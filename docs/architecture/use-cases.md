# Use Cases — Where Business Logic Lives

Read this **before adding logic** to a BLoC, a repository, or a widget. Most "where should
this go?" questions have the same answer: a use case.

Companion documents:
- `docs/architecture/layers.md` — three-layer rules and import lists
- `docs/architecture/bloc-rules.md` — BLoC rules, with Violation 1 and Violation 2

---

## 1. What Belongs in a Use Case

A use case is the **only** place that owns business decisions. Specifically:

- Validating business rules (e.g. "discount ≤ 50%", "tax code length", "settlement total
  must equal sum of items").
- Stamping domain-relevant timestamps (`insertionDate`, `lastModified`).
- Assigning identifiers when the database does not own them.
- Deciding "create vs update", "new vs existing", "draft vs published".

> **DB-owned identity (the default here).** Every Floor model uses
> `@PrimaryKey(autoGenerate: true)` on an `int? id`, so SQLite assigns the id on insert.
> The use case therefore **must not** fabricate an id (`copyWith(id: 0)` is the old bug
> that caused `UNIQUE constraint failed` on the second insert). `isNew` is simply
> `entity.id == null`; create passes `id == null`, update passes the real id.
- Orchestrating multiple repositories (e.g. "create settlement and update customer
  balance in one operation").
- Enforcing cross-entity invariants ("cannot delete a category that has items").

A use case is **not** the place for:

- Try/catch on infrastructure exceptions — that is the repository's job. The use case
  returns whatever `DataState` the repository gives it (or wraps with a domain-specific
  exception).
- JSON parsing — `data/`.
- Building widgets — `presentation/`.

---

## 2. Use Case Signatures

Base classes in `lib/core/utils/use_case.dart`:

```dart
// ✅ correct — base contracts, pure Dart
abstract class UseCaseBase<T> {
  Future<DataState<T>> call();
}

abstract class UseCaseWithRequest<T, R> {
  Future<DataState<T>> call(R request);
}
```

> The parameterised variant is `UseCaseWithRequest`, **not** `UseCaseWithParams`. Always
> extend `UseCaseWithRequest` for parameterised use cases.

### Simple delegation (no extra logic)

```dart
// ✅ correct — forwards to the repository
class GetByIdCustomerUseCase
    extends UseCaseWithRequest<Customer, GetByIdCustomerRequest> {
  final CustomerRepository _customerRepository;
  GetByIdCustomerUseCase(this._customerRepository);

  @override
  Future<DataState<Customer>> call(GetByIdCustomerRequest request) =>
      _customerRepository.getById(request.id);
}
```

Even when there is no extra logic, the use case stays — it preserves the seam between BLoC
and repository and keeps the test boundary clear.

---

## 3. Worked Refactor — Violation 2

This is the canonical example: the BLoC was deciding the customer's identity, stamping
timestamps, and routing between create and update. All of those are domain decisions.

### ❌ Before — Violation 2 (BLoC making domain decisions)

```dart
// ❌ wrong — _onSave inside CustomerEditBloc
Future<void> _onSave(
  SaveCustomerEvent event,
  Emitter<CustomerEditState> emit,
) async {
  final now = DateTime.now().toIso8601String();
  final customer = event.customer.copyWith(
    id: _customerId ?? 0,
    insertionDate: _isNew ? now : event.customer.insertionDate,
  );
  final result = _isNew
      ? await _createCustomerUseCase(CreateCustomerRequest(customer: customer))
      : await _updateCustomerUseCase(UpdateCustomerRequest(customer: customer));
  if (result is DataSuccess) {
    emit(CustomerEditSaved());
  } else {
    emit(CustomerEditError(result.exception?.toString() ?? _l10n.errorUnknown));
  }
}
```

Three layered problems (see `bloc-rules.md` §3):

1. The BLoC assigns the entity's ID (`id: _customerId ?? 0`).
2. The BLoC stamps `insertionDate`.
3. The BLoC decides create-vs-update.

All three are domain rules. The BLoC is acting as half a use case.

### ✅ After — single `SaveCustomerUseCase`

The use case owns the decision. The BLoC forwards the user's intent verbatim.

**Domain — request:**

```dart
// ✅ correct — lib/features/customers/domain/usecases/save_customer_use_case/model/save_customer_request.dart
class SaveCustomerRequest {
  final Customer customer;   // raw form payload; id == null → create, non-null → update
  const SaveCustomerRequest({required this.customer});
}
```

> No `customerId` field. The DB owns identity, so "create vs update" is derived from
> `customer.id == null` — a separate id would be redundant and risks disagreeing with the
> entity.

**Domain — use case:**

```dart
// ✅ correct — lib/features/customers/domain/usecases/save_customer_use_case/save_customer_use_case.dart
class SaveCustomerUseCase
    extends UseCaseWithRequest<void, SaveCustomerRequest> {
  final CustomerRepository _customerRepository;
  SaveCustomerUseCase(this._customerRepository);

  @override
  Future<DataState<void>> call(SaveCustomerRequest request) {
    final isNew = request.customer.id == null;
    if (isNew) {
      final customer = request.customer.copyWith(
        insertionDate: DateTime.now().toIso8601String(),
      );
      return _customerRepository.create(customer); // returns DataState<int> (new id)
    }
    return _customerRepository.update(request.customer);
  }
}
```

> The use case never assigns the id. On create it stamps `insertionDate` only and leaves
> `id == null` so Floor's `autoGenerate` assigns it. `repository.create` returns
> `DataState<int>` (the generated id); the save flow upcasts it to `DataState<void>` because
> nothing here needs it — `void` is a top type, so `DataState<int>` is a `DataState<void>`.

**Presentation — BLoC:**

```dart
// ✅ correct — BLoC forwards intent, if/else on result
Future<void> _onSave(
  SaveCustomerEvent event,
  Emitter<CustomerEditState> emit,
) async {
  final result = await _saveCustomerUseCase(
    SaveCustomerRequest(customer: event.customer),
  );

  if (result case DataFailed(:final exception)) {
    emit(CustomerEditError(exception));
    return;
  }

  emit(CustomerEditSaved());
}
```

### Alternative — split into `CreateCustomerUseCase` + `UpdateCustomerUseCase`

If create and update genuinely diverge (different validation rules, different audit
trails), keep them as separate use cases and let the BLoC pick:

```dart
// ✅ correct alternative — BLoC picks, but neither stamps timestamps nor assigns IDs
Future<void> _onSave(...) async {
  final isNew = event.customer.id == null;
  final result = isNew
      ? await _createCustomerUseCase(
          CreateCustomerRequest(customer: event.customer),
        )
      : await _updateCustomerUseCase(
          UpdateCustomerRequest(customer: event.customer),
        );
  // ... pattern match ...
}
```

Each use case owns its own ID and timestamp logic internally. The BLoC still routes — but
that is a *navigation* decision, not a *domain* decision. The use cases themselves do not
trust the BLoC to have stamped anything.

**Default to a single `SaveCustomerUseCase`** unless create and update need to diverge.

---

## 4. Use Case File Layout

```
lib/features/{feature}/domain/usecases/
└── {action}_{entity}_use_case/
    ├── {action}_{entity}_use_case.dart
    └── model/                              # only for parameterised use cases
        └── {action}_{entity}_request.dart
```

Class naming: `{Method}{EntitySingular}UseCase` — `GetByIdCustomerUseCase`,
`SaveCustomerUseCase`, **not** `GetByIdCustomersUseCase`.

Request naming: `{Method}{EntitySingular}Request` — `SaveCustomerRequest`,
`GetByIdCustomerRequest`.

---

## 5. DI Registration

Every use case has a matching `ProxyProvider` in
`lib/features/{feature}/data/repositories/di/{entity}_repository_providers.dart`:

```dart
// ✅ correct — DI chain
ProxyProvider<CustomerRepository, SaveCustomerUseCase>(
  update: (_, repo, __) => SaveCustomerUseCase(repo),
),
```

The `new_repository` / `feature_complete` Mason bricks generate this chain. Standalone
`new_usecase` / `new_usecase_with_request` bricks do **not** register the `ProxyProvider`
— the agent must add it manually and re-run `analyzeFiles`.

---

## 6. Quick Self-Check

Before you finish a BLoC handler, ask:

- [ ] Does the handler *derive* domain data from `DateTime.now()` (e.g. filter "today's
      rows", stamp an entity's timestamp)? → move into a use case. (Reading `now()` for a
      pure display/UX default is fine.)
- [ ] Does it `.copyWith(id: ...)` an entity before saving? → move into a use case.
- [ ] Does it branch on `_isNew` to pick a use case? → consider collapsing into one
      `Save{Entity}UseCase`.
- [ ] Does it `?? _l10n.errorXxx` after `result.exception`? → see `bloc-rules.md` §2, the
      `??` is dead code and the `_l10n` injection is forbidden.
- [ ] Does it return early on validation that the use case should own? → move the
      validation into the use case.
