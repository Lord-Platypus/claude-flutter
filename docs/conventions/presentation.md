# Presentation Layer Conventions

Read this **before editing any file under `lib/features/*/presentation/`**.

Covers: BLoCs, UI widgets, navigation, user-facing strings. This is the layer that produces
most violations — every rule below is Zero Tolerance.

---

## 1. User-Facing Strings (Zero Tolerance)

A string is **user-facing** if it can ever appear on screen: labels, titles, button text,
placeholders, snackbar messages, error messages, dialog text, empty-state copy.

### The rule

Every user-facing string comes from `l10n`. Never write a literal string in widget code
that is shown to the user.

### Forbidden (❌ wrong)

```dart
// ❌ literal title in UI
Text('Edit customer');
// ❌ hardcoded error message
SnackBar(content: Text('Unknown error'));
```

### Required (✅ correct)

```dart
// ✅ all user copy from l10n
Text(context.appLocalization.customersEditTitleEdit);
SnackBar(content: Text(context.appLocalization.errorUnknown));
```

### Error messages — translate in widgets, not BLoCs

BLoCs emit typed `Exception` (or sealed failure variants). Widgets translate via
`AppLocalizations.translateException` from
`lib/core/extensions/app_localizations_extensions.dart`.

```dart
// ✅ correct — widget translates exception
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

```dart
// ❌ wrong — l10n in BLoC, ?? fallback is dead code (DataFailed.exception is non-null)
emit(CustomerEditError(result.exception?.toString() ?? _l10n.errorUnknown));
```

See `docs/architecture/bloc-rules.md` §1 (No Localization in BLoCs) and §2 (`DataState`
consumption) for the canonical rule and the Violation 1 anti-example.

### Localization API rules

- Source ARB: `lib/core/localization/arbs/app_it.arb` (Italian, single locale).
- Generated files: `lib/core/localization/l10n/`.
- Regenerate:
  ```bash
  flutter gen-l10n --arb-dir=lib/core/localization/arbs --template-arb-file=app_it.arb --output-localization-file=app_localizations.dart --output-dir=lib/core/localization/l10n
  ```
- **Never** use `AppLocalizations.of(context)!` or assign `final l10n = AppLocalizations.of(context)!;`.
  Always use the `BuildContext` extension: `context.appLocalization`. The `AppLocalizations`
  import is still needed for type annotations (e.g. BLoC constructor).

### When string composition IS allowed

Template literals and `$interpolation` are allowed for **non-user-facing identifiers** like
codes, paths, log lines, `debugPrint`:

```dart
// ✅ identifier, not translated copy
String get code => 'C-$year-${id.toString().padLeft(3, '0')}';

// ✅ debug log
debugPrint('[CustomerRepositoryImpl] getById error: $e');
```

A formatted ID like `C-2026-001` is an **identifier**, not a translated label. Compose freely.
The rule applies to translated copy, not to programmatic IDs.

---

## 2. No Logic in UI (Zero Tolerance)

UI widgets render state. They do **not** make decisions. Anything that involves a domain
choice — "are we creating or editing?", "should this button be visible?", "what label here
based on entity status?" — belongs in the BLoC. The widget reads the answer from state.

### Forbidden in `build()` and `State` methods

- Sentinel checks: `if (customerId == 'new') ...`, `id == -1`, `id == 0`.
- Mode flags computed in the widget: `final isNew = widget.customerId == 'new';`,
  `final isEditable = customer.status == 'draft';`.
- Parsing path parameters mid-tree: `int.parse(customerId)` outside the route builder.
- Business validation: tax-code length, age-from-birthdate, discount eligibility.
- Mapping raw exception messages to display strings (BLoC emits localized state; UI shows it).
- **Derivations / aggregations:** date filtering ("today's sales"), sums ("today's takings"),
  grouping. The BLoC emits the computed result from a use case; the widget renders it.
- **Entity invariants:** clamping a cart quantity to stock, recomputing a total. The entity
  or use case owns these (`domain.md §2`); the widget never enforces them.
- **Imports from another feature's `presentation/`.** A feature's widgets/blocs/extensions
  must not import another feature's presentation layer — share via the domain layer or a
  `lib/core/` helper. See `docs/architecture/layers.md` §4 and `architecture.md` §1.

### Required

BLoC state carries the answer. Widget pattern-matches the state and renders.

```dart
// ❌ BAD
final isNew = widget.customerId == 'new';
Text(isNew ? l10n.customersEditTitleNew : l10n.customersEditTitleEdit);

// ✅ GOOD — BLoC state exposes a typed mode or pre-resolved title
switch (state) {
  CustomerEditCreateMode() => Text(l10n.customersEditTitleNew),
  CustomerEditEditMode()   => Text(l10n.customersEditTitleEdit),
}
// or: state has a `titleKey` field the BLoC populates.
```

**Narrow carve-out:** pure layout/presentation logic (responsive breakpoints, animation
curves, text overflow). That is presentation, not domain.

---

## 2.1. No Use-Case Calls in UI (Zero Tolerance)

A widget **never invokes a use case**. The UI dispatches an **event**; the BLoC owns the use
case and calls it; the widget reads the result from state. This holds everywhere — `onTap`,
`onPressed`, `initState`, a `FutureBuilder.future`, a dialog `load:` callback, a passed-in
`Future Function()`. If a widget is `await`-ing a use case, or holds a `UseCase` field, or
reads one from `context` to call it, that is the violation.

### The one allowed use-case reference in a widget

Wiring a use case **into a BLoC constructor**, inside `BlocProvider`'s `create:`. The widget
hands the use case to the BLoC and never calls it itself:

```dart
// ✅ correct — use case is wired into the BLoC, not invoked
BlocProvider(
  create: (ctx) => ItemsListBloc(
    watchProductRowsUseCase: ctx.read<WatchProductRowsUseCase>(),
    filterProductRowsUseCase: ctx.read<FilterProductRowsUseCase>(),
  )..add(const StartedItemsListEvent()),   // UI dispatches an event
  child: const _ItemsListScaffold(),
)
```

### Forbidden

```dart
// ❌ wrong — widget reads a use case and calls it in onTap
onTap: () {
  final detailUseCase = context.read<GetProductDetailUseCase>();
  showDialog(
    context: context,
    builder: (_) => ProductDetailDialog(
      load: () async => detailUseCase(GetProductDetailRequest(itemId: id)), // ❌ UI calls use case
      onArchive: () => context.read<ArchiveItemUseCase>()(...),             // ❌ UI calls use case
    ),
  );
}

// ❌ wrong — widget holds use cases as fields and invokes them
class SaleDetailDialog extends StatefulWidget {
  final GetSaleDetailUseCase getSaleDetailUseCase;        // ❌ use case in a widget
  final MarkSaleItemReturnedUseCase markSaleItemReturnedUseCase;
}
// ... widget.getSaleDetailUseCase(request)                // ❌ UI invokes it
```

### Required — dialogs and async sections are BLoC-driven too

A detail dialog, a `FutureBuilder`, an async load — all get a BLoC. The **page** wraps the dialog
in a `BlocProvider` whose BLoC loads on a `Started` event and handles mutations (archive, return)
through their own events, and renders `Loading/Loaded/Error` with a `BlocBuilder`. The dialog
widget stays **dumb**: it receives resolved data + plain callbacks and references **no BLoC and no
use case**. A callback may *dispatch an event* but must never *call a use case* — a closure that
calls a use case is the same violation regardless of where it is defined.

```dart
// ✅ correct — page owns the BLoC; dialog is dumb (data + callbacks)
showDialog(
  context: context,
  builder: (_) => BlocProvider(
    create: (ctx) => ProductDetailBloc(
      getProductDetailUseCase: ctx.read<GetProductDetailUseCase>(),
      archiveItemUseCase: ctx.read<ArchiveItemUseCase>(),
      itemId: id,
    )..add(const StartedProductDetailEvent()),
    child: BlocBuilder<ProductDetailBloc, ProductDetailState>(
      builder: (ctx, state) => switch (state) {
        ProductDetailLoading() => const AppLoader(),
        ProductDetailError()   => AppErrorWidget(
          message: ctx.appLocalization.translateException(state.exception),
        ),
        ProductDetailLoaded()  => ProductDetailDialog(
          view: _toView(state.detail),                                  // formatting = presentation
          onEdit: () => ctx.pushNamed(/* ... */),
          onArchive: () =>
              ctx.read<ProductDetailBloc>().add(ArchiveProductEvent(id)), // ✅ dispatch, not call
        ),
      },
    ),
  ),
);
```

```dart
// ❌ wrong — dialog is dumb, but the callback still CALLS the use case
ProductDetailDialog(
  onArchive: () => ctx.read<ArchiveItemUseCase>()(ArchiveItemRequest(itemId: id)),
);
```

See `bloc-rules.md` §11 for the BLoC side.

---

## 2.2. BLoCs Are Referenced Only in the Page (Zero Tolerance)

Only the **page** — the widget that owns the `BlocProvider` — may reference its BLoC:
`BlocProvider` / `BlocBuilder` / `BlocConsumer` / `BlocListener`,
`context.read/watch/select<XBloc>`, `BlocProvider.of`, and `bloc.add(event)`. **Sub-widgets never
touch the BLoC.** They receive plain data through their constructor and report user intent through
**callbacks** (`VoidCallback`, `ValueChanged<T>`, `void Function(...)`). The page maps BLoC state →
child props, and turns each child callback into a `bloc.add(event)`.

The page is the single seam between the UI tree and the BLoC. This keeps sub-widgets pure and
reusable, makes them testable without a BLoC, and stops bloc wiring from leaking through the tree.

### Forbidden — a sub-widget reaching into the BLoC

```dart
// ❌ wrong — filter bar reads the BLoC and dispatches events itself
class ItemsListFilterBar extends StatelessWidget {
  const ItemsListFilterBar({super.key, required this.state});
  final ItemsListSuccess state;

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      onChanged: (q) =>
          context.read<ItemsListBloc>().add(SearchItemsEvent(q)),   // ❌ bloc in a widget
    );
  }
}
```

### Required — page owns the BLoC, widget takes callbacks

```dart
// ✅ correct — widget is BLoC-agnostic: data in, callbacks out
class ItemsListFilterBar extends StatelessWidget {
  const ItemsListFilterBar({
    super.key,
    required this.state,
    required this.onSearchChanged,
    required this.onCategoryChanged,
  });

  final ItemsListSuccess state;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onCategoryChanged;

  @override
  Widget build(BuildContext context) =>
      AppSearchField(onChanged: onSearchChanged);
}

// page (owns the BlocProvider) wires callback → event:
ItemsListFilterBar(
  state: state,
  onSearchChanged: (q) => context.read<ItemsListBloc>().add(SearchItemsEvent(q)),
  onCategoryChanged: (id) => context.read<ItemsListBloc>().add(CategoryFilterChangedEvent(id)),
)
```

**"Page" = the `BlocProvider` owner**, even when it is a `*_tab` / `StatelessWidget` rather than a
`*_page`. Its direct children below that point use callbacks. Dialogs follow the same rule — see
§2.1: the page provides the BLoC + `BlocBuilder`, the dialog stays a dumb data+callbacks widget.

---

## 3. BLoC Rules

### Constructor — usecases as private fields

Inject usecases as private underscore-prefixed fields via initialiser list. **Never inject
`AppLocalizations`** — see `docs/architecture/bloc-rules.md` §1.

```dart
// ✅ correct
class CustomerDetailBloc extends Bloc<CustomerDetailEvent, CustomerDetailState> {
  final GetByIdCustomerUseCase _getByIdCustomerUseCase;
  final int _customerId;

  CustomerDetailBloc({
    required GetByIdCustomerUseCase getByIdCustomerUseCase,
    required int customerId,
  })  : _getByIdCustomerUseCase = getByIdCustomerUseCase,
        _customerId = customerId,
        super(CustomerDetailLoading()) {
    on<StartedCustomerDetailEvent>(_onStarted);
  }
}
```

- Domain identifiers (`customerId`, etc.) injected via constructor are also private
  underscore-prefixed unless the UI genuinely needs to read them from the BLoC.

### State design

- **Sealed classes only.** No enum-based states.
- Initial state:
  - Pages whose `Started` event fires immediately on mount → initial state = `XLoading()`
    (matches `new_page` brick).
  - Pages with no auto-start event → initial state = `XInitial()`.
- States must extend `Equatable` with `props`.
- **Error states carry `Exception`, not `String`.** Widgets translate via
  `context.appLocalization.translateException(state.exception)`. See
  `docs/architecture/bloc-rules.md` §1.

### `DataState` consumption

`DataState<T>` is a **sealed ADT** (see `lib/core/utils/data_state.dart`). The abstract base
has no `.data` or `.exception` fields — those live on the variants. `DataSuccess<T>.data` is
non-null `T`. `DataFailed<T>.exception` is non-null `Exception`.

Destructure the failure with a pattern `if`-case — never `switch` a closed two-case type, and
never rely on a bare `is` test to promote a field access on a concretely-typed `DataState<T>`
(see `bloc-rules.md §10`):

```dart
// ✅ correct — destructure the failure and return
final result = await _useCase(request);

if (result case DataFailed(:final exception)) {
  emit(CustomerError(exception));
  return;
}

emit(CustomerLoaded((result as DataSuccess).data));
```

For `Future<DataState<void>>` (create/update/delete) ignore `data`:

```dart
// ✅ correct — void result, same if-case shape
if (result case DataFailed(:final exception)) {
  emit(CustomerError(exception));
  return;
}

emit(CustomerSaved());
```

```dart
// ❌ wrong — fallback string is dead code; DataFailed.exception is non-null
emit(CustomerError(result.exception?.toString() ?? 'Unknown'));

// ❌ wrong — l10n in BLoC, dead fallback (Violation 1)
emit(CustomerError(result.exception?.toString() ?? _l10n.errorUnknown));
```

Full rules + Violation 1 walkthrough: `docs/architecture/bloc-rules.md` §2.

---

## 4–12. Navigation, design system & widget organisation (split out)

The rest of the presentation rules moved into two companion files (section numbers kept stable):

- **`docs/conventions/presentation-navigation.md`** — §4 Navigation: dashboard shell, destinations
  enum, `GoRoute` child/root paths, `pushNamed`/`goNamed`, "new vs edit" typed nullable.
- **`docs/conventions/presentation-design-system.md`** — §5 `App*` widgets, §6 theme/tokens,
  §7 widget file size, §8 `dispose()`, §9 async + `mounted`, §10 form validation pointer,
  §11 extension methods, §12 class member ordering.

Read the matching file before editing routes/navigation or any widget's visual building blocks,
theme values, or file structure.

