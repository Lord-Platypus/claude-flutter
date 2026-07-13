# Mason Bricks Reference — Feature / Repository / Page / Entity scaffolding

Per-brick parameter schemas for the feature-scaffolding bricks. Split out of `bricks.md` (the
index). **Read `bricks.md` first** — the critical naming rules and the mandatory two-step
procedure live there and apply to every brick below. Brick numbers kept stable (§1–§4).

Usecase, test, and presentation/asset bricks (§5–§11) are in
`docs/bricks-reference-usecases.md`.

---

## 1. `feature_complete` ⭐ (preferred entry-point)

Scaffolds an **entire feature** in one command by orchestrating `new_repository` and `new_page`
internally. Use this brick whenever you are creating a brand-new feature from scratch.

### Full two-step invocation example

```bash
# Step 1 – write the config file
cat > /tmp/my_feature_vars.json << 'EOF'
{
  "feature_name": "users",
  "entity_name":  "User",
  "fields": [
    { "name": "id",    "type": "int"    },
    { "name": "name",  "type": "String" },
    { "name": "email", "type": "String" }
  ],
  "methods": [
    {
      "name":        "getAll",
      "return_type": "List<User>",
      "has_param":   false,
      "param_name":  "",
      "param_type":  ""
    },
    {
      "name":        "getById",
      "return_type": "User",
      "has_param":   true,
      "param_name":  "id",
      "param_type":  "int"
    },
    {
      "name":        "create",
      "return_type": "void",
      "has_param":   true,
      "param_name":  "user",
      "param_type":  "User"
    },
    {
      "name":        "delete",
      "return_type": "void",
      "has_param":   true,
      "param_name":  "id",
      "param_type":  "int"
    }
  ],
  "pages": [
    {
      "page_name":   "UsersList",
      "bloc_name":   "UsersList",
      "bloc_events": ["LoadUsersEvent"],
      "usecases":    ["GetAllUserUseCase"]
    },
    {
      "page_name":   "UserDetail",
      "bloc_name":   "UserDetail",
      "bloc_events": ["LoadUserDetailEvent"],
      "usecases":    ["GetByIdUserUseCase"]
    }
  ]
}
EOF

# Step 2 – run the brick
mason make feature_complete \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/my_feature_vars.json
```

### Variable reference

| Variable       | Type   | Description                                                                                                      |
|----------------|--------|------------------------------------------------------------------------------------------------------------------|
| `feature_name` | string | Feature folder name – **plural snake_case** (e.g. `"users"`)                                                     |
| `entity_name`  | string | Entity class name – **singular PascalCase** (e.g. `"User"`)                                                      |
| `fields`       | list   | Entity fields. Each item: `{ "name": string, "type": string }`. Omit `id` – it is always added as `@primaryKey`. |
| `methods`      | list   | Repository methods. See schema below.                                                                            |
| `pages`        | list   | Pages/BLoC pairs. See schema below.                                                                              |

#### `methods` item schema

| Key           | Type    | Required              | Description                                               |
|---------------|---------|-----------------------|-----------------------------------------------------------|
| `name`        | string  | ✅                     | Dart method name, camelCase (e.g. `"getAll"`)             |
| `return_type` | string  | ✅                     | Verbatim Dart return type (e.g. `"List<User>"`, `"void"`) |
| `has_param`   | boolean | ✅                     | `true` if the method takes a parameter                    |
| `param_name`  | string  | when `has_param=true` | Dart parameter name (e.g. `"id"`)                         |
| `param_type`  | string  | when `has_param=true` | Dart parameter type (e.g. `"int"`)                        |

#### `pages` item schema

| Key           | Type   | Required | Description                                                                                                                                                                                                |
|---------------|--------|----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `page_name`   | string | ✅        | PascalCase page name (e.g. `"UsersList"`) → becomes folder `users_list/`                                                                                                                                   |
| `bloc_name`   | string | ✅        | PascalCase BLoC name (e.g. `"UsersList"`) → `UsersListBloc`                                                                                                                                                |
| `bloc_events` | list   | ✅        | List of extra event name strings. Use `[]` if none.                                                                                                                                                        |
| `usecases`    | list   | ✅        | List of usecase class names to inject into the BLoC (e.g. `["GetAllUserUseCase"]`). These are created by `new_repository`; names follow the pattern `{MethodNamePascalCase}{EntityNamePascalCase}UseCase`. |
| `path`        | string | ❌        | Custom route path (e.g. `"/users/:id"`). If omitted: first page → `/{feature_name}`, others → `/{feature_name}/{page_name_snake}`. Supports go_router path params.                                         |

### Generated files

`feature_complete` also generates:

- **`data/datasources/local/di/{entity}_local_datasource_providers.dart`** — Single provider
  function for local datasource (DAO injected inline from `AppDatabase` — no separate DAO provider).
- **`data/repositories/di/{entity}_repository_providers.dart`** — Provider functions for
  repository, usecases, and composed `{entity}Providers()`.
- **`presentation/navigation/{feature}_destinations.dart`** — Enum with one value per page.
- **`presentation/navigation/{feature}_route_provider.dart`** — Top-level function using
  `pageBuilder` + `MultiProvider(providers: {entity}Providers(), child: Page())` for each route.
  No BLoC injection at route level — BLoCs use `ctx.read<T>()` inside page widgets.

After generation, register the route provider in `lib/core/navigation/router.dart`:

```dart
import '../../features/users/presentation/navigation/users_destinations.dart';
import '../../features/users/presentation/navigation/users_route_provider.dart';

// In AppRouter constructor:
routes: [
usersRouteProvider
(),]
,
```

> ⚠️ **Conflict rule**: `--on-conflict skip` is always used. Re-running the brick on an existing
> feature is safe — already-generated files are left untouched.

---

## 2. `new_repository` (standalone)

Use when adding a **new entity + repository** to an existing feature, without creating new pages.
Internally calls `new_entity`.

```bash
# Step 1 – write the config file
cat > /tmp/repo_vars.json << 'EOF'
{
  "feature_name": "users",
  "entity_name":  "User",
  "fields": [
    { "name": "id",   "type": "int"    },
    { "name": "name", "type": "String" }
  ],
  "methods": [
    {
      "name": "getAll", "return_type": "List<User>",
      "has_param": false, "param_name": "", "param_type": ""
    }
  ]
}
EOF

# Step 2 – run the brick
mason make new_repository \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/repo_vars.json
```

---

## 3. `new_page` (standalone)

Use when adding a **new page + BLoC** to an existing feature (entity and usecases already exist).

When navigation files exist (`presentation/navigation/`), the post-gen hook automatically:

- Adds a new destination to the `{feature}_destinations.dart` enum.
- Adds a new `GoRoute` and import to `{feature}_route_provider.dart`.

```bash
# Step 1 – write the config file
cat > /tmp/page_vars.json << 'EOF'
{
  "feature_name": "users",
  "page_name":    "UserDetail",
  "bloc_name":    "UserDetail",
  "bloc_events":  ["LoadUserDetailEvent"],
  "usecases":     ["GetByIdUserUseCase"],
  "page_path":    "/users/:id"
}
EOF

# Step 2 – run the brick
mason make new_page \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/page_vars.json
```

### Variable reference

| Variable       | Type   | Required | Description                                                                                                                                 |
|----------------|--------|----------|---------------------------------------------------------------------------------------------------------------------------------------------|
| `feature_name` | string | ✅        | Feature folder name (snake_case)                                                                                                            |
| `page_name`    | string | ✅        | Page name (PascalCase)                                                                                                                      |
| `bloc_name`    | string | ✅        | BLoC name (PascalCase)                                                                                                                      |
| `bloc_events`  | list   | ❌        | Additional event name strings. Default: `[]`                                                                                                |
| `usecases`     | list   | ❌        | Usecase class names to inject. Default: `[]`                                                                                                |
| `entity_name`  | string | ❌        | Entity class name (PascalCase). Auto-passed by `feature_complete`. Default: `""`                                                            |
| `page_path`    | string | ❌        | Custom route path (e.g. `"/users/:id"`). If empty, auto-derived as `/{feature}/{page_snake}`. Supports go_router path params. Default: `""` |

The BLoC itself (bloc + event + state) is generated by **`new_bloc`** (§3b), which the post-gen
hook invokes with `bloc_path = page_name` so the bloc nests under `presentation/{page}/bloc/`.
The bloc/event/state templates live in `new_bloc` only — there is no duplicate copy in `new_page`.

---

## 3b. `new_bloc` (standalone)

Use when adding a **standalone BLoC** (bloc + event + state, no page) to an existing feature —
e.g. a detail-dialog bloc that a page wraps in a `BlocProvider`. Generates the sealed
`{Bloc}Event`/`{Bloc}State` classes (`Loading` initial / `Success` / `Error(Exception)`), a
`Started{Bloc}Event`, any extra events as TODO handlers, and injects usecases as private
constructor fields. **No brick exists otherwise for a page-less bloc — use this, never hand-roll**
(CLAUDE.md §4 brick-first).

`new_page` composes this brick; `feature_complete` → `new_page` → `new_bloc` transitively.

```bash
# Step 1 – write the config file
cat > /tmp/bloc_vars.json << 'EOF'
{
  "feature_name": "items",
  "bloc_name":    "ProductDetail",
  "bloc_path":    "product_detail",
  "bloc_events":  ["ArchiveProductEvent"],
  "usecases":     ["GetProductDetailUseCase", "ArchiveItemUseCase"]
}
EOF

# Step 2 – run the brick
mason make new_bloc \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/bloc_vars.json
```

Generates `lib/features/{feature}/presentation/{bloc_path}/bloc/{bloc}_bloc.dart` + `_event.dart`
+ `_state.dart`. The scaffold emits `Loading`/`Success`/`Error` states — rename/extend to the
real states (e.g. `Loaded(payload)`, transient one-shots) per `bloc-state-patterns.md`, and fill
the `//TODO` handlers (call usecases via the `DataState` if-case, `bloc-rules.md` §2/§11).

### Variable reference

| Variable       | Type   | Required | Description                                                                                                  |
|----------------|--------|----------|--------------------------------------------------------------------------------------------------------------|
| `feature_name` | string | ✅        | Feature folder name (snake_case)                                                                            |
| `bloc_name`    | string | ✅        | BLoC name (PascalCase, e.g. `ProductDetail` → `ProductDetailBloc`)                                          |
| `bloc_path`    | string | ❌        | Presentation subfolder holding `bloc/` (snake_case). Empty → defaults to the bloc name. `new_page` passes the page folder. Default: `""` |
| `bloc_events`  | list   | ❌        | Additional event name strings (each gets a TODO handler). Default: `[]`                                     |
| `usecases`     | list   | ❌        | Usecase class names to inject as private ctor fields. Default: `[]`                                         |

---

## 4. `new_entity` (standalone)

Use when you need **only** the entity class, Floor model, and DAO.

```bash
# Step 1 – write the config file
cat > /tmp/entity_vars.json << 'EOF'
{
  "feature_name": "users",
  "entity_name":  "User",
  "fields": [
    { "name": "id",   "type": "int"    },
    { "name": "name", "type": "String" }
  ]
}
EOF

# Step 2 – run the brick
mason make new_entity \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/entity_vars.json
```

### Rich, typed entities (R5 + R6)

The brick generates entities that are **born compliant** with the architecture rules. Two
optional inputs drive this — omit both and the output is a plain anemic entity (backward
compatible).

**Typed fields — `kind` (per-field, R6).** Mark enum fields with `"kind": "enum"`. The
entity field keeps the enum type; the Floor model persists it as `String` and the
`fromEntity`/`toEntity` mappers emit the `e.f.name` ↔ `Enum.values.byName(f)` seam. `DateTime`
and `bool` are detected from the `type` string automatically — no `kind` needed — and get the
`toIso8601String()` ↔ `DateTime.parse(...)` (stored as `String`) and `? 1 : 0` ↔ `== 1`
(stored as `int`) seams respectively. Nullable variants (`DateTime?`, enum?, `bool?`) are
handled. **The enum's Dart file is NOT generated** — author it in
`domain/entities/<enum>.dart` (colocated); the brick only imports it.

**Value-object fields — `kind: "money"` / `kind: "quantity"`.** Mark a field `"kind": "money"`
(`type: "Money"`) or `"kind": "quantity"` (`type: "Quantity"`). The entity field keeps the VO
type; the Floor model persists the raw `int` (cents for Money, count for Quantity) and the
mappers emit `e.f.cents` ↔ `Money.fromCents(f)` / `e.f.value` ↔ `Quantity(f)`. Nullable variants
(`Money?`, `Quantity?`) are handled. Both files import `core/value_objects/<vo>.dart` (dedup'd).
**The VO is NOT generated** — `Money`/`Quantity` already live in `lib/core/value_objects/`; the
brick only imports them.

**Construction invariants — `invariants` (top-level list, R5).** Each item is
`{ field, condition, message }` where `condition` is the **failure** check. When present, the
entity gets a private `const E._(…)` + a public validating `factory E(…)` that throws
`ArgumentError.value` then returns `._`; `copyWith` routes through the factory so it
re-validates. Omit `invariants` → the entity keeps a plain `const` constructor.

> `invariants` and per-field `kind` are **not declared in `brick.yaml`** (declaring a list var
> makes mason prompt for it when a config omits it). They flow through `--config-path` to the
> hook regardless. Just include them in the JSON.

```bash
cat > /tmp/entity_vars.json << 'EOF'
{
  "feature_name": "items",
  "entity_name":  "Item",
  "fields": [
    { "name": "name",      "type": "String"     },
    { "name": "status",    "type": "ItemStatus", "kind": "enum" },
    { "name": "createdAt", "type": "DateTime"    },
    { "name": "archivedAt","type": "DateTime?"   },
    { "name": "active",    "type": "bool"        },
    { "name": "quantity",  "type": "int"         }
  ],
  "invariants": [
    { "field": "quantity", "condition": "quantity < 0", "message": "must be >= 0" }
  ]
}
EOF
mason make new_entity --output-dir . --on-conflict skip --config-path /tmp/entity_vars.json
```

Renders (abridged): entity with `factory Item({…}) { if (quantity < 0) throw
ArgumentError.value(quantity, 'quantity', 'must be >= 0'); return Item._(…); }`; model with
`final String status;` + `status: e.status.name` / `status: ItemStatus.values.byName(status)`
and `createdAt: e.createdAt.toIso8601String()` / `createdAt: DateTime.parse(createdAt)`.
