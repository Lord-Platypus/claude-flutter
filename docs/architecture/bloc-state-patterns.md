# BLoC Construction & State Patterns

The longer worked examples split out of `bloc-rules.md` (which stays the index of the
zero-tolerance BLoC rules). Read this **before building a BLoC's constructor and state classes**.
Section numbers are kept stable (§5, §6, §7, §8) so existing cross-references resolve.

Companion documents:
- `docs/architecture/bloc-rules.md` — the zero-tolerance BLoC rules (l10n, `DataState`, handlers)
- `docs/conventions/presentation.md` — UI conventions (widgets, navigation, design system)

---

## 5. Constructor Shape

Inject use cases as **private underscore-prefixed** fields via the initialiser list:

```dart
// ✅ correct
class CustomerDetailBloc
    extends Bloc<CustomerDetailEvent, CustomerDetailState> {
  final GetByIdCustomerUseCase _getByIdCustomerUseCase;
  final UpdateCustomerUseCase _updateCustomerUseCase;
  final int _customerId;

  CustomerDetailBloc({
    required GetByIdCustomerUseCase getByIdCustomerUseCase,
    required UpdateCustomerUseCase updateCustomerUseCase,
    required int customerId,
  })  : _getByIdCustomerUseCase = getByIdCustomerUseCase,
        _updateCustomerUseCase = updateCustomerUseCase,
        _customerId = customerId,
        super(CustomerDetailLoading()) {
    on<StartedCustomerDetailEvent>(_onStarted);
  }
}
```

Do **not** add an `AppLocalizations` parameter (`bloc-rules.md` §1).

---

## 6. UI-side Translation Pattern

```dart
// ✅ correct — widget listens for error state, translates Exception
BlocConsumer<XBloc, XState>(
  listener: (context, state) {
    if (state is XError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.appLocalization.translateException(state.exception),
          ),
        ),
      );
    }
  },
  builder: (context, state) {
    return switch (state) {
      XLoading() => const AppLoader(),
      XError() => AppErrorWidget(
        message: context.appLocalization.translateException(state.exception),
      ),
      XSuccess() => _XContent(state: state),
    };
  },
)
```

`translateException` lives in
`lib/core/extensions/app_localizations_extensions.dart`. Add a case there when introducing
a new exception type.

---

## 7. State Is the Single Source of Truth — No Shadow State (Zero Tolerance)

A BLoC must not keep mutable private fields that **duplicate data already in the emitted
state** and get rebuilt on every event ("shadow state"). The emitted state is the one source
of truth. Read prior values from `state`, compute the next value, emit it via `copyWith`.
Parallel `_field` accumulators drift out of sync with the UI and are untestable.

### ❌ Wrong — shadow `_cart` field mirrored into state on every emit

```dart
// ❌ wrong — _cart is a second copy of what the state already holds
class CashRegisterBloc extends Bloc<CashRegisterEvent, CashRegisterState> {
  final List<CartLine> _cart = [];          // ❌ shadow state

  void _onAddItem(AddItemEvent e, Emitter emit) {
    _cart.add(CartLine(e.item, 1));          // ❌ mutate private field
    emit(CashRegisterLoaded(cart: List.of(_cart)));  // ❌ rebuild state from shadow
  }

  void _onRemoveItem(RemoveItemEvent e, Emitter emit) {
    _cart.removeWhere((l) => l.item == e.item);
    emit(CashRegisterLoaded(cart: List.of(_cart)));
  }
}
```

### ✅ Correct — one state class, read from `state`, emit derived

```dart
// ✅ correct — no private field; prior value comes from `state`
class CashRegisterBloc extends Bloc<CashRegisterEvent, CashRegisterState> {
  void _onAddItem(AddItemEvent e, Emitter emit) {
    final s = state;
    if (s is! CashRegisterLoaded) return;
    emit(s.copyWith(cart: [...s.cart, CartLine(e.item, 1)]));
  }

  void _onRemoveItem(RemoveItemEvent e, Emitter emit) {
    final s = state;
    if (s is! CashRegisterLoaded) return;
    emit(s.copyWith(cart: s.cart.where((l) => l.item != e.item).toList()));
  }
}
```

Prefer a **status-based** loaded state (one class with a `status` enum field + `copyWith`)
over many sibling classes when the same data is present across phases — it makes "read prior,
emit derived" the natural path and removes the temptation to cache fields outside state.

---

## 8. Transient Outcomes Are Their Own States — Not Nullable Fields (Zero Tolerance)

A one-shot result (a sale completed, a save failed, a toast to show once) must be modelled as
a **distinct state**, never as a nullable field hung on a long-lived success state. A
`Exception? saleError` on the loaded state forces every `copyWith` to remember to clear it,
leaks the error across rebuilds, and defeats exhaustive `switch` handling.

### ❌ Wrong — transient error as a nullable field on the success state

```dart
// ❌ wrong — saleError rides along on the persistent state
class CashRegisterLoaded extends CashRegisterState {
  final List<CartLine> cart;
  final Exception? saleError;          // ❌ transient outcome as a field
  final bool saleCompleted;            // ❌ another transient flag
}
```

### ✅ Correct — distinct states for the one-shot outcomes

```dart
// ✅ correct — separate states; the listener reacts once, then UI returns to Loaded
sealed class CashRegisterState extends Equatable { ... }
class CashRegisterLoaded extends CashRegisterState {
  final List<CartLine> cart;           // only persistent data
}
class CashRegisterSaleCompleted extends CashRegisterState {
  final List<CartLine> cart;           // carry data needed to re-render
}
class CashRegisterSaleFailed extends CashRegisterState {
  final List<CartLine> cart;
  final Exception exception;           // typed, non-null (see `bloc-rules.md` §1)
}
```

The widget pattern-matches these in a `BlocConsumer.listener` (snackbar, navigation) and the
`builder` stays exhaustive. No flag to remember to reset.
