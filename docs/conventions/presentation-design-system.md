# Presentation — Design System, Theme & Widget Organisation

Split out of `presentation.md` (which stays the index of presentation-layer rules). Read this
**before editing any widget's visual building blocks, theme values, or file structure** under
`lib/features/*/presentation/`. Section numbers kept stable (§5–§12) so existing cross-references
resolve.

Companion documents:
- `docs/conventions/presentation.md` — strings, no-logic-in-UI, BLoC rules (§1–§3)
- `docs/conventions/presentation-navigation.md` — routes, destinations, `go_router` (§4)
- `docs/conventions/forms-and-validation.md` — form validators + field layout

---

## 5. Design System Widgets — `App*` is mandatory

If an `App*` widget exists in `lib/core/app_design_system/widgets/`, the raw
Material/Cupertino equivalent is **forbidden** inside a feature. Add new tokens/widgets to
the design system rather than reimplementing inline.

| Raw Flutter widget                                                   | Required `App*` replacement   | Notes                                                                |
|----------------------------------------------------------------------|-------------------------------|----------------------------------------------------------------------|
| `CircularProgressIndicator`                                          | `AppLoader`                   | Loading state inside any page.                                       |
| `Text(errorMessage)` as placeholder                                  | `AppErrorWidget`              | Accepts optional `onRetry` + `retryLabel` (both localised).          |
| `TextFormField` / `TextField`                                        | `AppTextField`                | Multiline notes → set `maxLines`. Validators required inside `Form`. |
| Search input                                                         | `AppSearchField`              | Primary purpose = search.                                            |
| `ElevatedButton` / `FilledButton` / `OutlinedButton` / `TextButton`  | `AppButton`                   | Use `AppButtonVariant` for visual variants.                          |
| `Chip` / `RawChip`                                                   | `AppChip`                     |                                                                      |
| `Badge` / coloured count circle                                      | `AppBadge`                    |                                                                      |
| `Card` / `Material` "card" wrapper                                   | `AppSectionCard`              |                                                                      |
| `MaterialBanner` / inline alert                                      | `AppAlertBanner`              |                                                                      |
| `showDialog` with confirm/cancel                                     | `AppConfirmDialog`            |                                                                      |
| Coloured status dot                                                  | `AppStatusDot`                |                                                                      |
| `CircleAvatar`                                                       | `AppAvatar`                   |                                                                      |
| Segmented control                                                    | `AppSegmentedControl`         |                                                                      |

The `new_page` brick scaffolds loader/error correctly. Manually written pages must mirror.

Field layout — wrapping error messages and top-aligning rows of fields — is in
`forms-and-validation.md` §3.

---

## 6. Theme — no inline colors or sizes ever

- All visual values come from `context.theme.*`. **No exceptions inside features.**
- If a colour/dimension is missing, **add it to the abstract token + the concrete light theme**
  in `lib/core/app_design_system/theme/token/` and `lib/theme/token/`. Never use
  `const Color(0x...)` inside a feature file.
- File-private hex constants (`const Color _kFoo = Color(0x...)`) are forbidden — they hide
  from the design system and break dark-mode portability.
- File-private dimension constants are allowed for one-off layout values (e.g.
  `const double _kMaxFormWidth = 600;`).

---

## 7. Widget File Size & Organisation

- Widget files must stay **under 500 lines**. If a file exceeds this, extract subwidgets.
- Pages with multiple distinct sub-sections (tabs, panels, complex cards) decompose each
  subwidget into its own file inside a `widgets/` subfolder:

```
presentation/customers_list/ui/
├── customers_list_page.dart
└── widgets/
     ├── customer_card.dart
     └── customer_list_filter_bar.dart
```

- Class names must be specific and immediately show their feature origin.
  Bad: `TopBar` — Good: `DashboardTopBar`. Any widget inside a feature folder is prefixed
  with the feature name.

---

## 8. `dispose()` discipline

- Every `addListener(...)` requires a matching `removeListener(...)` **before** disposing the
  node.
- Every `TextEditingController`, `FocusNode`, `AnimationController`, `ScrollController`,
  `StreamSubscription` created in `initState` must be disposed in `dispose`.
- Order in `dispose`: remove listeners → dispose owned nodes → `super.dispose()`.

---

## 9. Async + `mounted`

- After every `await` in a `State` method, check `if (!mounted) return;` before touching
  `setState`, `context`, or `Navigator`.
- Includes `showDialog`, `showDatePicker`, `Future.delayed`, and any usecase call.

---

## 10. Form Validation

Moved to its own doc: **`docs/conventions/forms-and-validation.md`**. It covers the baseline
(`validator` on every field, validate-before-save, inline errors) **and** the Zero-Tolerance
rule that form validators must mirror domain invariants — out-of-range input shows inline at
the field, never only in a log. Read it before editing a form or any widget that builds an
entity/value object from text fields.

---

## 11. Extension Methods

When the same inline expression is repeated or verbose, extract an extension method.

- Feature-scoped extensions: `lib/features/{feature}/presentation/extensions/`.
- Domain/cross-feature extensions: `lib/core/extensions/`.
- Name extensions after the type they extend, e.g. `extension CustomerCode on Customer`,
  `extension ErrorTranslation on AppLocalizations`. (Form *validators* are not an
  `AppLocalizations` extension — they live in `FormValidators`; see `forms-and-validation.md` §1.)

---

## 12. Class Member Ordering — Helpers at the Bottom

Private helpers, mappers (`_toView`), and event handlers go at the **bottom of the class**,
after `build`. Never as free functions at the top of the file, never above `build`.

Order within a widget:

**`StatefulWidget` class:** static constants → final fields → constructor → `createState`.

**`State` class:** state fields → getters (derived state) → lifecycle
(`initState` / `didChangeDependencies` / `didUpdateWidget` / `dispose`) → `build` →
**everything else last** (handlers, mappers, helpers).

```dart
// ❌ wrong — free function above the class
ItemView _toView(Item item) => ItemView(name: item.name);

class ItemsListPage extends StatelessWidget { ... }
```

```dart
// ✅ correct
class ItemsListPage extends StatefulWidget {
  static const double defaultPadding = 16.0;   // 1. constants

  final String title;                          // 2. fields

  const ItemsListPage({super.key, required this.title});   // 3. constructor

  @override
  State<ItemsListPage> createState() => _ItemsListPageState();
}

class _ItemsListPageState extends State<ItemsListPage> {
  late int _count;                             // 1. state fields

  String get _formattedCount => 'Count: $_count';  // 2. getters

  @override
  void initState() {                           // 3. lifecycle
    super.initState();
    _count = 0;
  }

  @override
  Widget build(BuildContext context) {         // 4. build
    return Text(_toView(_count));
  }

  // 5. everything else LAST — handlers, mappers, helpers
  String _toView(int value) => 'Item $value';

  void _increment() {
    setState(() {
      _count++;
    });
  }
}
```

> Lint status: partial. `sort_constructors_first` enforces constructor placement; full member
> ordering (helpers after `build`) is review-only.
