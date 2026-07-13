# Architecture Conventions

Folder structure, DI flow, layer boundaries, naming. Read this **before creating any new
file** in a feature.

## 1. Layer Boundaries

| Layer          | Imports allowed                                                | Forbidden                                                              |
|----------------|----------------------------------------------------------------|------------------------------------------------------------------------|
| `domain/`      | Pure Dart, `package:equatable`, `lib/core/utils/*`             | Flutter, Floor, JSON, BLoC, `AppLocalizations`, anything in `data/`    |
| `data/`        | Domain, Floor, JSON, sqflite, `debugPrint`                     | Flutter widgets, `BuildContext`, BLoC, `AppLocalizations`              |
| `presentation/`| Domain, Flutter, BLoC, design system, `AppLocalizations` (widgets only) | Floor, direct DAO, raw `sqflite`, `AppLocalizations` inside BLoCs |

**Strict rules:**

- **NO** Flutter or Floor imports in `domain/`.
- **NO** business logic in BLoCs or Repositories. Business logic lives in **UseCases**.
- **NO** direct DB access from BLoCs.
- **NO** bypassing the Repository layer.
- **NO** `AppLocalizations` import inside a BLoC. Localization lives in widgets only —
  BLoCs emit typed `Exception`, widgets translate via `translateException`.
- **NO** identity assignment, timestamp stamping, or create-vs-update decisions inside
  BLoCs. Those are use case responsibilities.
- **NO** cross-feature presentation imports. `features/<a>/presentation/` must never import
  `features/<b>/presentation/`. Features share only via the **domain** layer. Promote shared
  presentation helpers (e.g. a feature-agnostic `ProductDetailDialog`) to `lib/core/`.
  **Two exemptions:** (1) navigating to another feature's route **by name** is allowed (a
  route name is a shared contract, not a widget/bloc import); (2) the **composition root** —
  the dashboard shell route provider (`dashboard_route_provider.dart`) — may import feature
  presentation to compose routes and inject widgets (e.g. passing `CategoriesTab` into
  `SettingsPage`), because composing features is its job. See `docs/architecture/layers.md` §4.

Full layer rules with import lists and decision table:
`docs/architecture/layers.md`. BLoC-specific rules and Violation 1 / Violation 2
walkthroughs: `docs/architecture/bloc-rules.md` and `docs/architecture/use-cases.md`.

## 2. Folder Structure (mandatory per feature)

Every feature lives in `lib/features/{feature_name}/` with exactly these subfolders:

```
lib/features/{feature_name}/
├── domain/
│   ├── entities/
│   ├── exceptions/                  # {feature}_exceptions.dart — pure Dart, manually created
│   ├── repositories/                # abstract classes
│   └── usecases/
│       └── {action}_{entity}_use_case/
│           ├── {action}_{entity}_use_case.dart
│           └── model/{action}_{entity}_request.dart   # only for parameterised usecases
├── data/
│   ├── dao/
│   ├── datasources/
│   │   ├── local/
│   │   │   ├── {entity}_local_datasource.dart            # abstract
│   │   │   ├── {entity}_local_datasource_impl.dart
│   │   │   └── di/{entity}_local_datasource_providers.dart
│   │   └── remote/                                       # if applicable
│   │       └── di/{entity}_remote_datasource_providers.dart
│   ├── models/                                           # {entity}_model.dart + .g.dart
│   └── repositories/
│       ├── {entity}_repository_impl.dart
│       └── di/{entity}_repository_providers.dart
└── presentation/
    ├── navigation/
    │   ├── {feature}_destinations.dart                   # enum: path + name
    │   └── {feature}_route_provider.dart                 # top-level function → RouteBase
    ├── extensions/                                        # feature-scoped extensions
    └── {page_name}/
        ├── bloc/
        │   ├── {page_name}_bloc.dart
        │   ├── {page_name}_event.dart                    # part of bloc
        │   └── {page_name}_state.dart                    # part of bloc
        └── ui/
            ├── {page_name}_page.dart
            └── widgets/                                  # extracted subwidgets
```

## 3. DI Flow (Provider / ProxyProvider — NEVER `get_it`)

Provider chain assembled per route, BLoC injected in page widget.

```
main.dart
  └── MultiProvider(providers: await initGlobalProviders())   [core/di/injection.dart]
        └── Provider<AppDatabase>                              (global singleton)
              │
              ▼  (injected per-route in route_provider via MultiProvider(providers: xxxProviders()))
       ProxyProvider<AppDatabase, XLocalDatasource>           [data/datasources/local/di/]
              │   (DAO read inline: `db.xDao` — no separate DAO provider)
              ▼
       ProxyProvider<XLocalDatasource, XRepository>           [data/repositories/di/]
              │
              ▼
       ProxyProvider<XRepository, GetAllXUseCase>             [data/repositories/di/]
       ProxyProvider<XRepository, GetByIdXUseCase>            (one ProxyProvider per usecase)
              │
              ▼
       BlocProvider(create: (ctx) => XBloc(useCase: ctx.read<GetAllXUseCase>()))
                                                              [in page widget, NOT route]
```

- `{entity}Providers()` is a `List<SingleChildWidget>` chaining datasource + repository +
  all usecases. Lives in `data/repositories/di/{entity}_repository_providers.dart`.
- `new_repository` / `feature_complete` Mason bricks generate the full chain.
- **Standalone `new_usecase` / `new_usecase_with_request` do NOT register the ProxyProvider** —
  agent must manually append `ProxyProvider<XRepository, NewUseCase>` to
  `{entity}_repository_providers.dart`.

## 4. Naming Cheat-Sheet

Read this before creating any class or file.

**English-only.** Every identifier, type, file, and folder name is English — no Italian. Use
`CashRegisterProductTile`, not `CassaProductTile`; `number`, not `numero`. Only user-facing
copy is Italian, and that lives exclusively in the ARB (`l10n`). See `code-quality.md §9`.

### Singular vs plural

| Artifact                                  | Form                          | Example                                                          |
|-------------------------------------------|-------------------------------|------------------------------------------------------------------|
| Feature folder (`lib/features/X`)         | **plural** snake_case         | `customers`, `items`, `sales`                                    |
| Entity class                              | **singular** Pascal           | `Customer`, `Item`, `Sale`                                       |
| Entity file                               | **singular** snake            | `customer.dart`                                                  |
| Model file                                | **singular** snake            | `customer_model.dart`                                            |
| DAO class / file                          | **singular** Pascal / snake   | `CustomerDao` / `customer_dao.dart`                              |
| Repository class                          | **singular** Pascal           | `CustomerRepository`                                             |
| Usecase class                             | `{Method}{EntitySingular}UseCase` | `GetAllCustomerUseCase` (NOT `GetAllCustomersUseCase`)       |
| Usecase folder + file                     | snake_case of class           | `get_all_customer_use_case/get_all_customer_use_case.dart`       |
| Request class (for `UseCaseWithRequest`)  | `{Method}{EntitySingular}Request` in `usecase_folder/model/{name}_request.dart` | `GetByIdCustomerRequest` |
| Page folder                               | snake_case page name          | `customer_detail/`, `customer_edit/`, `customers_list/`          |
| Page class                                | `{PageName}Page`              | `CustomerDetailPage`                                             |
| BLoC class                                | `{PageName}Bloc`              | `CustomerDetailBloc`                                             |
| Event class                               | `{Action}{BlocName}Event`     | `StartedCustomerDetailEvent`, `SaveCustomerEditEvent`            |
| State class                               | `{BlocName}{StateKind}`       | `CustomerDetailLoading`, `CustomerDetailSuccess`                 |
| Destination enum value                    | camelCase page id             | `customerDetail`, `customerEdit`                                 |
| Widget inside feature                     | prefixed with feature/page    | `CustomersListFilterBar` — never `TopBar`                        |

### File / import style

- **Inside a feature** → relative imports (`../../domain/entities/customer.dart`).
- **Across features or to `core/` / `theme/`** → package imports
  (`package:volta_gestionale_mercatini/core/utils/data_state.dart`).
- Never mix the two styles for the same target.

## 5. Cross-feature Navigation

Routes are composed in `lib/core/navigation/router.dart` (`AppRouter`). Cross-feature
composition uses each feature's `childRoutes` parameter — **no direct feature-to-feature
imports**.

```dart
// lib/core/navigation/router.dart
customersRouteProvider(
  childRoutes: [
    settlementsRouteProvider(),   // nested settlements route under /customers/:id
  ],
),
```
