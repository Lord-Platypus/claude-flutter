# Forms & Validation Conventions

Rules for any page/dialog that takes user input and turns it into domain objects.
Read before editing a form, a `validator`, or any widget that constructs an entity/value
object from text fields.

Related: `domain.md` §9 (value objects), `architecture/bloc-rules.md` §1 (typed exceptions),
`presentation.md` §2 (no logic in UI).

---

## 1. Form Validation (baseline)

- Every `TextFormField` (or equivalent) inside a `Form` must define a `validator` callback.
- Never call `_formKey.currentState!.save()` without first calling
  `_formKey.currentState!.validate()`.
- Show validation errors inline; do not use SnackBars for field-level errors.
- Common validators live in `lib/core/utils/form_validators.dart` as `FormValidators.x(l10n)`
  factories: static methods returning a `FormFieldValidator<String>`, built from the
  `AppLocalizations` already in widget scope so each resolves its own message **inside** the
  validator — callers never thread a translated string. Validators are **not** extensions on
  `AppLocalizations`; validation logic is not the localization object's business.
  Known: `FormValidators.required(l10n)` (presence), `FormValidators.priceEuros(l10n)` (`Money`
  non-negative), `FormValidators.percent(l10n)` (`PercentageRule` `[0, 100]`).

`FormValidators.required(l10n)` checks presence only. A field bound to a constrained domain
concept needs more — see §2.

---

## 2. Surface Domain Invariants at the Input Boundary (Zero Tolerance)

### The ban

**NO** user input may reach an entity/VO constructor that can throw on it without the form
first validating against that same invariant. A violated invariant must be shown **inline at
the field that caused it** — never only logged.

`ArgumentError` from a VO/entity constructor is a **programmer-error** signal: validation that
should have happened at the boundary did not. It is not a user-facing channel. If the user can
type a value that trips it, that is a bug.

### Why

Domain invariants (`discount ∈ [0,100]`, `Money.cents >= 0`, `Quantity >= 1`) are the single
source of truth for *what is valid*. When the UI doesn't mirror them, the throw lands somewhere
with no path back to the user:

- thrown **inside a BLoC handler** → not a `DataFailed`, so `DataState` never sees it → escapes
  to `Bloc.onError` → `AppLogger` → log only;
- thrown **inside a widget callback** (`onPressed`) → Flutter framework catches → `FlutterError`
  → log only;

either way the dialog/page has already acted. User gets nothing. Looks like a no-op.

### Forbidden (❌ wrong)

```dart
// no Form, no validator — raw parse straight into a throwing constructor
void _save() {
  Navigator.of(context).pop(CategoryFormResult(
    discount: double.tryParse(_discount.text) ?? 0,   // "150" → 150
  ));
}
// later: Category(discount: 150) → throws ArgumentError, escapes to onError, only logged
```

```dart
// Form present but validator only checks presence
if (!_formKey.currentState!.validate()) return;        // "required" passes on "-5"
final price = Money.fromEuros(double.tryParse(text) ?? 0);  // Money.fromCents(-500) throws
```

### Required (✅ correct)

1. Wrap the dialog/page body in a `Form` with a `GlobalKey<FormState>`; save runs
   `_formKey.currentState!.validate()` and **returns early** if invalid. (Row editors without a
   `Form` must gain one, or carry a per-row error-text field.)
2. Each field bound to a constrained domain concept gets a `validator` that enforces the **same**
   invariant and returns an l10n message — range, not just `required`.
3. **Don't duplicate the bound.** Expose the invariant once on the domain type; both the
   constructor and the validator consume it, so the range can't drift. The validator itself lives
   in `FormValidators` (§1), **not** inline in the widget and **not** as an `AppLocalizations`
   extension:

```dart
// domain — single source of truth (core/value_objects/percentage_rule.dart)
abstract final class PercentageRule {
  static const double min = 0;
  static const double max = 100;
  static bool isValid(double value) => value >= min && value <= max;
}
// entity constructor uses it as a backstop
if (!PercentageRule.isValid(discount)) {
  throw ArgumentError.value(discount, 'discount', 'must be in [0, 100]');
}
// validator (core/utils/form_validators.dart) uses the SAME rule, resolves its own message
static FormFieldValidator<String> percent(AppLocalizations l10n) {
  return (value) {
    final v = double.tryParse(value?.trim() ?? '');
    if (v == null || !PercentageRule.isValid(v)) {
      return l10n.settingsCategoryPercentRangeError;   // "Inserisci un valore tra 0 e 100"
    }
    return null;
  };
}
// widget just wires it — no inline logic
validator: FormValidators.percent(l10n),
```

Same shape for `Money` (`cents >= 0` ⇒ `FormValidators.priceEuros(l10n)` rejects
negative/non-numeric) and `Quantity` (`>= 1`). The entity/VO `throw` stays as the **last-line
backstop** (defends domain if a non-form caller is added). The form is the **user-facing line**.

4. **VO constructed inside a BLoC**: the handler must guarantee its input was pre-validated
   upstream. If it cannot, catch the construction error → emit a typed exception state → widget
   translates (`bloc-rules.md` §1). Never let it escape to `onError`.

### Scope

Every field whose value feeds a VO/entity that can throw: `discount`, `commission`,
`Money.fromCents/fromEuros`, `Quantity`, `Email`, `Phone`, `FiscalCode`, `VatNumber`, `ZipCode`.
**New/edited form: check each field** — does its target type throw on bad input? → it needs a
validator mirroring that invariant.

### Checklist

- [ ] Dialog/page with input wrapped in `Form` + key; save gated on `validate()`.
- [ ] Every constrained field has a `validator` returning an l10n **range** message (not just `required`).
- [ ] Validator and constructor share one invariant definition (no duplicated bound).
- [ ] Entity/VO `throw` retained as backstop.
- [ ] VO built in a BLoC: input pre-validated, or caught → typed state.
- [ ] No invariant violation reachable by user input ends only in a log.

---

## 3. Field Layout & Error Display

Inline errors change a field's height. These two rules keep a form from looking broken the moment
a validator fires.

### Errors wrap, never truncate

A validation message must wrap to a second line instead of being cut off with an ellipsis. This is
owned by the design-system field widgets — `AppTextField` and `AppDropdownField` set
`errorMaxLines: 2` on their `InputDecoration`, so every feature gets it for free. Do **not**
re-truncate by wrapping a field in a fixed-height box.

### Rows of fields align to the top (Zero Tolerance)

Any `Row` holding **two or more sibling input fields** (`AppTextField`, `AppDropdownField`, or any
`App*Field`) must set `crossAxisAlignment: CrossAxisAlignment.start`.

When one field shows an error it grows taller. With the default (`center`) or `end` alignment, the
error-free siblings then shift vertically and the row looks misaligned. Top-aligning pins every
field's top edge and lets only the erroring field's message extend downward.

```dart
// ❌ wrong — default center alignment; an error on one field offsets the others
Row(children: [Expanded(child: AppTextField(...)), Expanded(child: AppTextField(...))])

// ✅ correct
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [Expanded(child: AppTextField(...)), Expanded(child: AppTextField(...))],
)
```

Exception: a `Row` pairing a single field with a non-field control (e.g. a labelled stepper) may use
a deliberate alignment — it is not a multi-field row and the misalignment failure mode doesn't apply.

### Checklist

- [ ] No field wrapped in a fixed-height box that would clip a wrapped error.
- [ ] Every `Row` with 2+ `App*Field` children sets `crossAxisAlignment: CrossAxisAlignment.start`.
