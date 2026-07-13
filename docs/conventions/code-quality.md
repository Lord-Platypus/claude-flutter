# Code Quality Conventions

Read this **before writing any non-trivial code**.

---

## 1. Method Design

- **Atomic methods:** every method/function does exactly one thing. If you need "and" to
  describe it, split it.
- **Guard clauses first:** handle edge cases and error paths at the top with early returns.
  Avoid nested `if/else`; use it only when branch symmetry genuinely aids readability.

---

## 2. No Magic Values

Every hardcoded number or string must be extracted to a named constant, even if used only
once.

```dart
// ❌ BAD
constraints: const BoxConstraints(maxWidth: 600),

// ✅ GOOD
const double _kMaxFormWidth = 600;
constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
```

- File-private constants (`const double _kFoo = 12;`) are allowed for one-off layout values.
- File-private **colour** constants are forbidden — colours go through the theme. See
  `presentation-design-system.md §6`.
- Route paths are already covered by the destinations enum — see `presentation-navigation.md §4`.
- User-facing strings go through `l10n` — see `presentation.md §1`.

---

## 3. DRY — spot and propose

- When the same inline expression appears **3+ times**, stop and propose centralisation to
  the user before writing the third copy.
- Prefer:
    - **Extension methods** for type-level behaviour (e.g. `CustomerCode on Customer`,
      `ErrorTranslation on AppLocalizations`). Note: form *validators* are **not** an
      `AppLocalizations` extension — they live in `FormValidators` (`forms-and-validation.md` §1).
    - **Named helpers** for stateless transformations.
    - **Constants** for repeated literals.
- Do not extract speculatively — only when the duplication is already present.

### Extension methods location

- Feature-scoped extensions: `lib/features/{feature}/presentation/extensions/`.
- Domain/cross-feature extensions: `lib/core/extensions/`.
- Name extensions after the type they extend.

---

## 4. Comments

- Prefer self-documenting names over comments.
- Add `///` doc comments only on public APIs whose logic or intent is non-obvious.
- Never write comments that merely restate what the code does.

---

## 5. Date Formatting

- Italian display format: `dd/MM/yyyy` (date) / `dd/MM/yyyy HH:mm` (date+time).
- Storage format: ISO 8601 via `DateTime.toIso8601String()`.
- Repeated more than twice → extract to an `extension DateTimeFormat on DateTime` in
  `lib/core/extensions/`.

---

## 6. Abstractions

Create an abstract class only when testability or substitutability requires it (e.g.
repository interfaces, datasource interfaces). Do not add interfaces speculatively.

---

## 7. String Composition vs User-Facing Strings

This rule trips up weaker models. Three distinct cases:

| Case                          | Rule                                                                | Example                                     |
|-------------------------------|---------------------------------------------------------------------|---------------------------------------------|
| Translated copy shown to user | Must use `l10n` (widget only — never inside a BLoC)                 | `Text(context.appLocalization.customerSave)` |
| Programmatic identifier       | String composition / interpolation OK                               | `'C-$year-${id.toString().padLeft(3, '0')}'` |
| Debug log / `debugPrint`      | String composition OK                                               | `debugPrint('[X] error: $e')`               |

If unsure: **would a user ever see this string?** If yes → `l10n` in a widget. If no →
compose freely.

### Exception translation pattern

BLoCs emit `Exception` in error states. Widgets translate via
`context.appLocalization.translateException(state.exception)`. Add new exception cases to
`lib/core/extensions/app_localizations_extensions.dart`.

```dart
// ✅ correct — widget translates
SnackBar(
  content: Text(
    context.appLocalization.translateException(state.exception),
  ),
);
```

```dart
// ❌ wrong — `??` fallback after non-null exception; l10n in BLoC
emit(XError(result.exception?.toString() ?? _l10n.errorUnknown));
```

Full rules: `presentation.md §1`, `docs/architecture/bloc-rules.md` §1–§2.

---

## 8. Branch Discipline

- Before starting any new task, verify the active branch is specific to that task.
- Run `git branch --show-current` and confirm the branch name matches the work.

---

## 9. English-Only Code (Zero Tolerance)

All code is English: identifiers, class/type names, file names, folder names, and comments.
No Italian (or any non-English) anywhere in code. The **only** Italian in the project is
user-facing copy, and that lives exclusively in the ARB files (`l10n`) — never as an
identifier.

```dart
// ❌ wrong — Italian type and field names
class CassaProductTile extends StatelessWidget { ... }   // ❌ "Cassa"
final int numero;                                        // ❌ "numero"
// calcola il totale del carrello                         // ❌ Italian comment
```

```dart
// ✅ correct — English identifiers; Italian only in the ARB shown to users
class CashRegisterProductTile extends StatelessWidget { ... }
final int number;
Text(context.appLocalization.cashRegisterTotal);          // "Totale" lives in app_it.arb
```

When you find a non-English identifier, **rename it consistently across the whole codebase**
(declaration, references, files, folders, tests) — a half-rename is worse than none.

---

## 10. Declare, Then Assign — No Work Inside Constructor/Call Arguments

Do not bury computation (an `await`, a function call, a ternary) inside the argument list of a
constructor or method call. Compute each value first, give it a name, then pass the named
variable. Applies **everywhere** — blocs, widgets, use cases.

```dart
// ❌ wrong — await + fallbacks buried in the constructor call
emit(ItemsListSuccess(
  rows: data,
  filteredRows: await _filter(data, query: prev?.query ?? '', categoryId: prev?.categoryId),
  query: prev?.query ?? '',
  categoryId: prev?.categoryId,
));
```

```dart
// ✅ correct — compute first, name it, then build
final query = prev?.query ?? '';
final categoryId = prev?.categoryId;
final filteredRows = await _filter(data, query: query, categoryId: categoryId);

emit(ItemsListSuccess(
  rows: data,
  filteredRows: filteredRows,
  query: query,
  categoryId: categoryId,
));
```

---

## 11. Short Code: Prefer Repetition Over Premature Abstraction

For small handlers, **repeat the few lines** rather than inventing a generic helper that hides
the work behind a callback. A `_reemit(emit, (s) => s.copyWith(...))`-style indirection for
three-line handlers is overengineering — the reader now has to jump to two places to see what
one event does. (This complements §3 DRY and §6 Abstractions: extract only when the repetition
is real and the abstraction earns its keep.)

```dart
// ❌ wrong — generic helper + arrow handlers hiding the actual work
Future<void> _onMaintenanceFilter(e, emit) =>
    _reemit(emit, (s) => s.copyWith(maintenanceFilter: e.filter));

Future<void> _reemit(Emitter emit, State Function(State) change) async { ... }
```

```dart
// ✅ correct — each handler does its own thing, plainly
Future<void> _onMaintenanceFilter(
  MaintenanceFilterChangedEvent event,
  Emitter<ItemsListState> emit,
) async {
  final current = state;

  if (current is! ItemsListSuccess) {
    return;
  }

  final filteredRows = await _filter(current.rows, maintenanceFilter: event.filter);

  emit(current.copyWith(
    maintenanceFilter: event.filter,
    filteredRows: filteredRows,
  ));
}
```

---

## 12. Blank-Line Blocking Inside Methods

Method bodies are split into visual blocks with blank lines. Enforce where a linter can; the
rest is review.

- Blank line **before** `if`, `for`, `while`, `return`, `emit`.
- Blank line **after** the closing brace of an `if`/`for`/`while` body.

```dart
// ❌ wrong — wall of statements
Future<void> _onStarted(e, emit) async {
  final current = state;
  if (current is! ItemsListSuccess) return;
  final rows = await _load();
  emit(current.copyWith(rows: rows));
}
```

```dart
// ✅ correct — blocked
Future<void> _onStarted(e, emit) async {
  final current = state;

  if (current is! ItemsListSuccess) {
    return;
  }

  final rows = await _load();

  emit(current.copyWith(rows: rows));
}
```

> Lint status: review-only. No off-the-shelf Dart lint covers "blank line before `emit`". If
> we want it enforced, it needs a custom `custom_lint` plugin rule — propose before building.

---

## 13. `await`, Never `.then`

Use `async`/`await` for all asynchronous flow. Never chain `.then(...)`.

```dart
// ❌ wrong
repository.getAll().then((result) => emit(Success(result)));
```

```dart
// ✅ correct
final result = await repository.getAll();
emit(Success(result));
```

---

## 14. Global Values vs Type Transforms — Where Things Live

Split a "value vs behavior" concern by what it is:

- A **raw global value** (a symbol, a key, a default) → a `const` in `lib/core/utils/` (or
  `lib/core/constants/`).
- A **transform/format on a type** → an **extension method on that type**, in
  `lib/core/extensions/` (cross-feature) — named after the type it extends.

```dart
// ❌ wrong — literal + manual formatting scattered at call sites
Text('€${price.toStringAsFixed(2)}');
```

```dart
// ✅ correct — raw value in core/utils, transform as an extension on the type
// core/utils/app_constants.dart
class AppConstants {
  static const String currencySymbol = '€';
}

// core/extensions/num_currency_extension.dart
extension NumCurrencyExtension on num {
  String toCurrency() => '${AppConstants.currencySymbol}${toStringAsFixed(2)}';
}

Text(price.toCurrency());
```

> **Exception — true domain concepts use value objects, not extensions.** Money is a domain
> concept, so it is a `Money` value object that owns its own `format()` (see `domain.md §9`),
> **not** a `num` extension. This §14 extension pattern is for values that are *not* domain
> concepts. Reach for the value object first.
