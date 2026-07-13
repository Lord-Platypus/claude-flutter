# BLoC Rules

Read this **before editing any BLoC** under `lib/features/*/presentation/*/bloc/`.

Every rule is mechanical. The two violations at the bottom (Violation 1 and Violation 2) are
the canonical anti-examples — quote them in code review when you see the pattern reappear.

Companion documents:
- `docs/architecture/bloc-state-patterns.md` — §5 constructor, §6 translation, §7 shadow state, §8 transient outcomes (split out)
- `docs/architecture/layers.md` — layer boundaries and import lists
- `docs/architecture/use-cases.md` — what belongs in a use case
- `docs/conventions/presentation.md` — UI conventions (widgets, navigation, design system)

---

## 1. No Localization in BLoCs (Zero Tolerance)

`AppLocalizations` is a UI concern. Injecting it into a BLoC pulls localization into the
presentation-logic layer, where it does not belong. The BLoC's job is to emit **typed**
errors; the widget translates them.

### Rule

A BLoC must not import `AppLocalizations` or any file under `lib/core/localization/`. No
`_l10n` field. No `l10n:` constructor parameter. Every error state carries an `Exception`
(or a sealed failure variant), never a pre-translated `String`.

### ❌ Wrong — Violation 1 (l10n injected, dead fallback)

```dart
// ❌ wrong — BLoC imports AppLocalizations and uses ?? _l10n.errorUnknown as fallback
class CustomerEditBloc extends Bloc<CustomerEditEvent, CustomerEditState> {
  final AppLocalizations _l10n;          // ❌ l10n in BLoC
  // ...
  Future<void> _onStarted(...) async {
    final result = await _getByIdCustomerUseCase(...);
    if (result is DataSuccess<Customer?> && result.data != null) {
      emit(CustomerEditSuccess(customer: result.data!));
    } else {
      // ❌ ?? _l10n.errorUnknown is dead code: DataFailed.exception is non-null
      emit(CustomerEditError(result.exception?.toString() ?? _l10n.errorUnknown));
    }
  }
}
```

Two problems:

1. **`l10n` is a UI concern.** BLoCs must not depend on `AppLocalizations`. Localization
   belongs in widgets.
2. **The `?? _l10n.errorUnknown` fallback is dead.** After the `else`, `result` is
   `DataFailed`. By construction, `DataFailed.exception` is non-null. The `??` branch can
   never fire. (Under the sealed-ADT `DataState`, this code does not even compile because
   the abstract base has no `.exception` field — see §2.)

### ✅ Correct

```dart
// ✅ correct — BLoC emits the Exception, no l10n dependency
class CustomerEditBloc extends Bloc<CustomerEditEvent, CustomerEditState> {
  final GetByIdCustomerUseCase _getByIdCustomerUseCase;
  // no _l10n field, no AppLocalizations import
  // ...
  Future<void> _onStarted(...) async {
    final result = await _getByIdCustomerUseCase(...);

    if (result case DataFailed(:final exception)) {
      emit(CustomerEditError(exception));               // ✅ typed, untranslated
      return;
    }

    emit(CustomerEditSuccess(customer: (result as DataSuccess).data));
  }
}
```

Error state:

```dart
// ✅ correct — error state carries Exception, not String
class CustomerEditError extends CustomerEditState {
  final Exception exception;
  const CustomerEditError(this.exception);
  @override
  List<Object?> get props => [exception];
}
```

Widget translates:

```dart
// ✅ correct — translation happens in the widget
if (state is CustomerEditError) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        context.appLocalization.translateException(state.exception),
      ),
    ),
  );
}
```

`translateException` is an extension on `AppLocalizations` defined in
`lib/core/extensions/app_localizations_extensions.dart`. Extend it when new exception types
need user-facing copy.

### Escalation — sealed failure variants

When the UI must discriminate between specific failure causes (e.g. "show retry" vs "show
contact support"), use a sealed error variant **instead of** a single `XError(Exception)`:

```dart
// ✅ correct — sealed variants when the UI must branch on failure cause
sealed class CustomerEditState extends Equatable { ... }
class CustomerEditNotFoundError extends CustomerEditState {
  const CustomerEditNotFoundError();
  @override List<Object?> get props => [];
}
class CustomerEditConflictError extends CustomerEditState {
  const CustomerEditConflictError();
  @override List<Object?> get props => [];
}
class CustomerEditGenericError extends CustomerEditState {
  final Exception exception;
  const CustomerEditGenericError(this.exception);
  @override List<Object?> get props => [exception];
}
```

Default is **`XError(Exception)`**. Escalate to sealed variants only when the UI genuinely
needs to switch on the cause.

---

## 2. `DataState<T>` Consumption (Zero Tolerance)

`DataState<T>` is a sealed ADT defined in `lib/core/utils/data_state.dart`:

```dart
// ✅ correct — sealed, non-null fields per variant
sealed class DataState<T> {
  const DataState();
}
class DataSuccess<T> extends DataState<T> {
  final T data;                  // non-null
  const DataSuccess(this.data);
}
class DataFailed<T> extends DataState<T> {
  final Exception exception;     // non-null
  const DataFailed(this.exception);
}
```

Implications:

- The abstract base has **no `.data` and no `.exception` fields**. Accessing them on the
  base will not compile.
- `DataSuccess.data` is `T` (non-null). If you need a nullable payload, use
  `DataSuccess<T?>` — the variant's `data` is then `T?`.
- `DataFailed.exception` is `Exception` (non-null). The `?? fallback` antipattern is
  impossible and forbidden.

### Required idiom — pattern `if`-case, never `switch`

`DataState` is a **closed two-case** type — `DataSuccess` and `DataFailed`, and it never grows
more. Do **not** `switch` over it (that is for open/growing sets). Destructure the failure with a
**pattern `if`-case**, emit, and return; the success path continues unindented. This is the
canonical idiom; §10 states the rule in full.

```dart
// ✅ correct — destructure the failure, emit, return; success continues unindented
final result = await _useCase(request);

if (result case DataFailed(:final exception)) {
  emit(XError(exception));
  return;
}

emit(XSuccess((result as DataSuccess).data));
```

For `Future<DataState<void>>` (create/update/delete) the success branch ignores `data`:

```dart
// ✅ correct — void result, same if-case shape
if (result case DataFailed(:final exception)) {
  emit(XError(exception));
  return;
}

emit(XSaved());
```

**Why pattern if-case, not `if (result is DataFailed)`?** A bare `is` test does **not**
type-promote a field access on a concretely-typed `DataState<T>`. `DataFailed` written with no
type argument infers to `DataFailed<Object?>`, which is **not** a subtype of (e.g.)
`DataState<int>`, so `result.exception` on the "promoted" branch does not compile. The pattern
`case DataFailed(:final exception)` binds the field directly and works for **every** `T` (concrete
and `void` alike). The success tail keeps one explicit cast `(result as DataSuccess).data` — that
is expected and lint-clean (no `unnecessary_cast`).

### Forbidden idioms

```dart
// ❌ wrong — fallback string is dead code; .exception is non-null on DataFailed
emit(XError(result.exception?.toString() ?? 'Unknown'));

// ❌ wrong — hardcoded user-facing string
emit(XError(result.exception?.toString() ?? 'Customer not found'));

// ❌ wrong — l10n fallback in BLoC (Violation 1)
emit(XError(result.exception?.toString() ?? _l10n.errorUnknown));

// ❌ wrong — .data / .exception on the un-guarded base
emit(XSuccess(result.data));        // compile error: base has no `.data`

// ❌ wrong — bare `is` does NOT promote field access for concrete T (won't compile)
if (result is DataFailed) {
  emit(XError(result.exception));   // compile error: result still DataState<int>
  return;
}

// ❌ wrong — switch over a closed two-case type (use the if-case — see §10)
switch (result) {
  case DataSuccess(:final data):     emit(XSuccess(data));
  case DataFailed(:final exception): emit(XError(exception));
}
```

If you find yourself writing `??` after `result.exception`, stop. The `??` branch cannot
fire. Use the pattern if-case idiom above (full rule in §10).

---

## 3. No Business Logic in BLoCs (Zero Tolerance)

A BLoC's job is:

1. Receive an event.
2. Call a use case with the event payload.
3. Emit a state based on the `DataState` result.

A BLoC **must not**:

- Assign identifiers (`id: _customerId ?? 0`).
- Stamp timestamps onto entities (`copyWith(insertionDate: ...)`) — that is a domain decision
  tied to create-vs-update; the use case owns it. (Reading `DateTime.now()` itself is fine;
  deciding *what timestamp an entity gets* is not.)
- Decide "create vs update" — see Violation 2.
- Validate business rules (e.g. "name length ≥ 2", "discount ≤ 50%").
- **Derive or aggregate domain data** — date filtering ("sales from today"), sums
  ("today's takings"), grouping. Those are use-case computations; the BLoC emits the result.
- **Enforce entity invariants** — e.g. clamping cart quantity to available stock. The entity
  (or use case) owns the invariant; the BLoC forwards intent and emits what comes back.
- Mutate entities beyond what the user typed.

All of these belong in a use case or the entity. See `use-cases.md` and `domain.md` §2.

### ❌ Wrong — Violation 2 (BLoC making domain decisions)

```dart
// ❌ wrong — BLoC assigns ID, stamps insertion date, decides new-vs-update
Future<void> _onSave(
  SaveCustomerEvent event,
  Emitter<CustomerEditState> emit,
) async {
  final now = DateTime.now().toIso8601String();          // ❌ timestamping in BLoC
  final customer = event.customer.copyWith(
    id: _customerId ?? 0,                                 // ❌ ID assignment in BLoC
    insertionDate: _isNew ? now : event.customer.insertionDate,
  );
  final result = _isNew
      ? await _createCustomerUseCase(CreateCustomerRequest(customer: customer))
      : await _updateCustomerUseCase(UpdateCustomerRequest(customer: customer));
  // ❌ BLoC routes between create/update — that decision is domain
  // ... emit ...
}
```

Three problems:

1. **The BLoC decides the customer's identity.** ID assignment is a domain rule (the
   database column might autoincrement; the constraint "ID must be unique" is domain).
2. **The BLoC stamps `insertionDate`.** Timestamps are domain state, not UI state.
3. **The BLoC decides "new vs existing".** That decision affects which use case runs, which
   table column is touched, and whether `insertionDate` is preserved. All domain concerns.

### ✅ Correct — BLoC forwards intent, use case decides

```dart
// ✅ correct — BLoC forwards the user's intent verbatim
Future<void> _onSave(
  SaveCustomerEvent event,
  Emitter<CustomerEditState> emit,
) async {
  final result = await _saveCustomerUseCase(
    SaveCustomerRequest(
      customerId: _customerId,        // null for create, int for update
      customer: event.customer,       // raw form payload, untouched
    ),
  );

  if (result case DataFailed(:final exception)) {
    emit(CustomerEditError(exception));
    return;
  }

  emit(CustomerEditSaved());
}
```

The `SaveCustomerUseCase` (or paired `CreateCustomerUseCase` / `UpdateCustomerUseCase`)
owns ID assignment, timestamping, and the create-vs-update branch. See `use-cases.md` for
the full worked refactor.

---

## 4. State Shape Rules

- **Sealed classes only.** No enum-based states.
- Every state `extends Equatable` with `props`.
- Initial state:
  - Pages whose `Started` event fires immediately on mount → initial = `XLoading()`
    (matches the `new_page` brick).
  - Pages without an auto-start event → initial = `XInitial()`.
- Error state carries an `Exception` (default) **or** a sealed failure variant — never a
  pre-translated `String`. See §1.

---

## 5–8. Construction & state patterns (split out)

The longer worked examples live in **`docs/architecture/bloc-state-patterns.md`** (section
numbers kept stable):

- **§5 — Constructor Shape.** Use cases as private underscore fields via the initialiser list;
  no `AppLocalizations` parameter.
- **§6 — UI-side Translation Pattern.** Widget `BlocConsumer` listens for the error state and
  translates the `Exception` via `context.appLocalization.translateException(...)`.
- **§7 — State Is the Single Source of Truth — No Shadow State (Zero Tolerance).** No mutable
  private `_field` accumulators that duplicate emitted state; read prior values from `state`,
  emit derived via `copyWith`.
- **§8 — Transient Outcomes Are Their Own States — Not Nullable Fields (Zero Tolerance).** A
  one-shot result (sale completed, save failed) is a distinct state, never a nullable field hung
  on a long-lived success state.

Read that file before building a BLoC's constructor and state classes.

---

## 9. One Handler Per Event — No Dispatcher Switch (Zero Tolerance)

Register **one `on<SpecificEvent>` per event type**, each pointing at its own handler method.
This is the Mason brick style. Do **not** funnel every event through a single `_onEvent`
method that `switch`es over the event type — it buries the wiring and fights the framework's
own type dispatch.

```dart
// ❌ wrong — single dispatcher + switch over events
on<ItemsListEvent>(_onEvent);

Future<void> _onEvent(ItemsListEvent event, Emitter<ItemsListState> emit) async {
  switch (event) {
    case StartedItemsListEvent():      await _onStarted(event, emit);
    case SearchItemsEvent():           await _onSearch(event, emit);
    case CategoryFilterChangedEvent(): await _onCategoryFilter(event, emit);
  }
}
```

```dart
// ✅ correct — one registration per event, direct handler
on<StartedItemsListEvent>(_onStarted);
on<SearchItemsEvent>(_onSearch);
on<CategoryFilterChangedEvent>(_onCategoryFilter);
```

**No event transformers.** Do not pass `transformer:` to any `on<E>` registration
(`sequential()`, `restartable()`, `droppable()`, `concurrent()`, or a custom one) — bloc
transformers are **banned without explicit user permission**. The default (concurrent)
processing applies. If handlers genuinely race on `state`, surface it and ask before adding any
transformer; never reach for one to paper over a dispatcher you should have split. (A single
`_onEvent` dispatcher is never the answer either — it is banned regardless.)

---

## 10. `DataState<T>` — pattern `if`-case, Never `switch` (refines §2)

`DataState` has exactly two cases — `DataSuccess` and `DataFailed` — and never grows more.
Do **not** `switch` over it. Destructure the failure with a pattern `if`-case, emit, and return;
the success path continues unindented. Never add a redundant `else if (result is DataSuccess)` —
anything that is not failure is success.

```dart
// ❌ wrong — switch over a closed two-case core type
switch (result) {
  case DataSuccess(:final data):      emit(Success(data));
  case DataFailed(:final exception):  emit(Failure(exception));
}

// ❌ wrong — bare `is` does not promote field access for concrete T (won't compile)
if (result is DataFailed) {
  emit(Failure(result.exception));    // compile error for DataState<int> etc.
  return;
}

// ❌ wrong — redundant else-if branch
if (result case DataFailed(:final exception)) {
  emit(Failure(exception));
} else if (result is DataSuccess) {
  emit(Success((result as DataSuccess).data));
}
```

```dart
// ✅ correct — destructure failure, emit, return; success path continues unindented
if (result case DataFailed(:final exception)) {
  emit(Failure(exception));
  return;
}

emit(Success((result as DataSuccess).data));

// ✅ correct — void result, same shape (success branch has no `.data`)
if (result case DataFailed(:final exception)) {
  emit(Failure(exception));
  return;
}

emit(Saved());
```

**Why not bare `is` + field access?** For a concretely-typed `DataState<T>`, a `DataFailed` /
`DataSuccess` test written with no type argument infers to `…<Object?>`, which is not a subtype of
`DataState<T>`, so `result.exception` / `result.data` do **not** promote and will not compile. The
pattern if-case binds the field directly for every `T`. Keep the single explicit
`(result as DataSuccess).data` cast on the success tail — it is lint-clean.

---

## 11. The BLoC Is the Only Caller of Use Cases (Zero Tolerance)

Use cases are invoked **only inside a BLoC handler**. The UI never calls one — it dispatches an
event, the handler calls the use case, the handler emits state. This is the presentation-side
mirror of `presentation.md` §2.1; read that for the UI half (the one allowed use-case reference
in a widget is wiring it into a BLoC constructor inside `BlocProvider`'s `create:`).

Concretely, the BLoC owns the full async lifecycle that the UI used to host in a dialog `load:`
callback or a `FutureBuilder`:

- A **load** (e.g. fetch a product/sale detail) → `Started` event → handler calls the read use
  case → emits `Loading` then `Loaded(view)` / `Error(exception)`.
- A **mutation** (archive an item, return a sale line) → its own event → handler calls the
  mutation use case → emits a transient outcome state (`bloc-state-patterns.md` §8) or re-emits `Loading`/reload.

```dart
// ✅ correct — handler is the only place the use case is called
Future<void> _onStarted(
  StartedProductDetailEvent event,
  Emitter<ProductDetailState> emit,
) async {
  emit(ProductDetailLoading());
  final result = await _getProductDetailUseCase(
    GetProductDetailRequest(itemId: _itemId),
  );

  if (result case DataFailed(:final exception)) {
    emit(ProductDetailError(exception));
    return;
  }

  emit(ProductDetailLoaded((result as DataSuccess).data));
}
```

A dialog, a `FutureBuilder`, or any async-loading widget is **not** an exception — it gets a
BLoC too. The widget pattern-matches the state and dispatches events; it holds no `UseCase`
field and reads none from `context` to call it.
