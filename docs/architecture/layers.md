# Architecture — Three Layer Rules

Read this **before touching any file under `lib/features/`**. Every rule is a mechanical check
you can verify line-by-line. No interpretation.

Companion documents:
- `docs/architecture/bloc-rules.md` — BLoC-specific rules (l10n, `DataState`, error states)
- `docs/architecture/use-cases.md` — what belongs in a use case, with worked refactor
- `docs/conventions/` — per-layer convention files (presentation, domain, data, testing…)

---

## 1. Layer Map

```
lib/features/{feature}/
├── domain/            # pure Dart — entities, usecases, repository interfaces, exceptions
├── data/              # repositories impls, datasources, DAOs, DTO/models, JSON, Floor
└── presentation/      # BLoCs, pages, widgets, navigation, design system
```

Dependency direction:

```
presentation  ─►  domain  ◄─  data
```

`domain` knows nothing about `data` or `presentation`. `data` and `presentation` depend on
`domain`. They never depend on each other.

---

## 2. Domain Layer — Pure Dart

Path: `lib/features/{feature}/domain/`

### Allowed imports

- `package:equatable/equatable.dart`
- Other domain files inside the same feature (relative imports).
- `lib/core/utils/data_state.dart`, `lib/core/utils/use_case.dart`,
  `lib/core/utils/exceptions.dart` (infrastructure-level shared types — pure Dart).

### Forbidden imports

- `package:flutter/*` — **any** Flutter import. If a domain file needs Flutter, the design is
  wrong.
- `package:floor/*`, `package:sqflite/*`, `package:json_annotation/*`, anything from
  `data/`.
- `package:flutter_bloc/*`, `package:provider/*`, `package:bloc/*` — no state management.
- `dart:io` — domain runs anywhere.
- Any `*_model.dart`, `*_dao.dart`, `*_local_datasource*.dart`, `*_repository_impl.dart` —
  those are data layer.
- `AppLocalizations` / anything under `lib/core/localization/` — domain emits typed errors,
  not localized strings.
- `ChangeNotifier`, `Cubit`, `Bloc`.

### What lives here

- **Entities**: immutable, `extends Equatable`, `copyWith`, rich (own their invariants —
  validate in constructors, value objects, intent-revealing methods; see `domain.md §2`).
  Dates are `DateTime`, statuses are enums — typed in the domain, stringified only at the
  data/mapping boundary (`domain.md §8`).
- **Repository interfaces**: abstract classes returning `Future<DataState<T>>`.
- **UseCases**: extend `UseCaseBase<T>` or `UseCaseWithRequest<T, R>`. See `use-cases.md`.
- **Exceptions**: feature-specific exceptions that the domain meaningfully distinguishes.

---

## 3. Data Layer — Infrastructure

Path: `lib/features/{feature}/data/`

### Allowed imports

- Everything in `domain/` of the same feature.
- `package:floor/*`, `package:sqflite_common_ffi/*`, `package:json_annotation/*`.
- `package:flutter/foundation.dart` — **only** for `debugPrint` inside `catch` blocks.
- `package:provider/*` for DI wiring under `data/.../di/`.

### Forbidden imports

- `package:flutter/material.dart`, `package:flutter/widgets.dart`, `package:flutter/cupertino.dart`.
- `BuildContext`. If a data-layer method needs `BuildContext`, the design is upside-down.
- Anything under `presentation/`.
- `package:flutter_bloc/*`.
- `AppLocalizations` — data does not know about localization.

### What lives here

- DAOs (`@dao` abstract Floor classes).
- LocalDatasource abstract + impl.
- RepositoryImpl — try/catch + `debugPrint` + wrap as `DataFailed(TypedException)`.
- Models (Floor `@Entity` + `@JsonSerializable`). A model **does not `extends` the domain
  entity** — it is a standalone class with `@PrimaryKey(autoGenerate: true) final int? id`
  and explicit `fromEntity` / `toEntity` mappers. This mapping seam is where DB-owned
  identity lives. See `data.md §5`.

### Hard rules

- **No business validation here.** Examples that **must** live in a use case, not the
  repository:
  - "name must be at least 2 characters"
  - "discount only allowed if customer is Gold"
  - "deletion only allowed if no children exist"

  The repository persists what it is told. The use case decides what is allowed.
- **No identity/timestamp assignment here** unless the database itself owns it (e.g.
  autoincrement column). Use cases stamp insertion dates and "is new" decisions. See
  `use-cases.md`.

---

## 4. Presentation Layer — UI

Path: `lib/features/{feature}/presentation/`

### Allowed imports

- Everything in `domain/` of the same feature.
- `package:flutter/*`.
- `package:flutter_bloc/*`, `package:provider/*`, `package:go_router/*`, `package:equatable/*`.
- `AppLocalizations` — **only inside widgets**, never inside a BLoC. See
  `bloc-rules.md` §1.
- `lib/core/app_design_system/*`, `lib/core/extensions/*`,
  `lib/core/localization/*`.

### Forbidden imports

- `package:floor/*`, `package:sqflite/*` — no direct DB access. Always go through the
  repository.
- `*_dao.dart`, `*_local_datasource*.dart`, `*_repository_impl.dart` — talk to interfaces
  only.
- `package:json_annotation/*` — no JSON parsing in widgets.
- `dart:io` (with the exception of `Platform.isXxx` if absolutely required — almost never).
- **Another feature's `presentation/`** — `package:.../features/<other>/presentation/...`.
  A feature's presentation layer must never import another feature's blocs, widgets, pages,
  or presentation extensions. Cross-feature communication goes through the **domain** layer
  (shared entities / use cases) and route composition via `childRoutes` (`architecture.md`
  §5). See the rule below.

### Hard rule — no cross-feature presentation dependencies

```dart
// ❌ wrong — sales presentation reaching into items presentation
import 'package:volta_gestionale_mercatini/features/items/presentation/extensions/item_tile_extension.dart';
```

```dart
// ✅ correct — depend on the shared domain entity, format locally (or via a core/ extension)
import 'package:volta_gestionale_mercatini/features/items/domain/entities/item.dart';
```

If two features need the same presentation helper, promote it to `lib/core/` — do not
import sideways. The agnostic core widget takes primitives + callbacks (a view model + a
`load`/`onAction` closure); each feature maps its own domain type into it. Example:
`core/app_design_system/widgets/product_detail_dialog.dart` (`ProductDetailView`), fed by
both items and customers.

**Exemptions (not violations):**
- **Navigation by route name.** Calling `context.pushNamed(OtherFeatureDestination.x.name)`
  is allowed — a route name is a shared contract, not a widget/bloc/extension import.
- **Composition root.** The dashboard shell route provider
  (`dashboard/presentation/navigation/dashboard_route_provider.dart`) may import any feature's
  presentation to compose its routes and **inject** widgets into another feature (e.g. passing
  `const CategoriesTab()` into `SettingsPage(categoriesTab:)` so `settings` itself never
  imports `categories`). Composing features is the shell's responsibility; ordinary feature
  code must still never import sideways.

### Hard rules

- **No business logic in widgets.** No domain decisions in `build()`. See
  `docs/conventions/presentation.md` §2.
- **No business logic in BLoCs.** The BLoC translates user events to use case calls and
  pattern-matches the result. See `bloc-rules.md` §3, `use-cases.md`.
- **No `AppLocalizations` in BLoCs.** BLoCs emit typed errors (`Exception` or sealed
  variants). Widgets translate. See `bloc-rules.md` §1.

---

## 5. Cross-Layer Idioms

### `DataState<T>` — sealed ADT

Defined in `lib/core/utils/data_state.dart`:

```dart
// ✅ correct — sealed ADT, non-null fields per variant
sealed class DataState<T> {
  const DataState();
}
class DataSuccess<T> extends DataState<T> {
  final T data;
  const DataSuccess(this.data);
}
class DataFailed<T> extends DataState<T> {
  final Exception exception;
  const DataFailed(this.exception);
}
```

Producers (repository, use case) return `DataSuccess(value)` or `DataFailed(exception)`.
Consumers (BLoC, other use cases) destructure the failure with a pattern `if`-case (never
`switch` a closed two-case type — see `bloc-rules.md §10`). The base class has no `.data` or
`.exception` — those live on the variants — and a bare `is` test does not promote a field
access on a concretely-typed `DataState<T>`.

```dart
// ✅ correct — destructure the failure, then use the cast success
if (result case DataFailed(:final exception)) {
  throw exception;                 // exception is Exception, non-null
}

return (result as DataSuccess).data;   // data is T, non-null
```

```dart
// ❌ wrong — `?? fallback` is dead code; DataFailed.exception is non-null by construction
emit(XError(result.exception?.toString() ?? 'Unknown'));
```

See `bloc-rules.md` §2 for the full consumption pattern and forbidden idioms.

---

## 6. Decision Table

When you don't know which layer a piece of code belongs to:

| Asking…                                            | Lives in        |
|----------------------------------------------------|-----------------|
| Parse JSON                                         | `data`          |
| Open a database connection                         | `data`          |
| Decide if an entity can be deleted                 | `domain` (use case) |
| Stamp `insertionDate`                              | `domain` (use case) |
| Decide create-vs-update                            | `domain` (use case) |
| Translate `Exception` → user message               | `presentation` (widget) |
| Show a `SnackBar`                                  | `presentation` (widget) |
| Validate "name length ≥ 2"                         | `domain` (use case) |
| Validate "field is non-empty" (form-level)         | `presentation` (widget validator) |
| Trigger navigation                                 | `presentation` (widget, via `context.go(...)`) |
| Map model ↔ entity                                 | `data` (model `fromEntity` / `toEntity`) |
| Define `Future<DataState<T>>` contract             | `domain` (repository interface) |
| Implement that contract with try/catch             | `data` (repository impl) |
