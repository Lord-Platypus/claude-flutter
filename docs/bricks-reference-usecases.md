# Mason Bricks Reference — Usecase / Test / Presentation / Asset bricks

Per-brick parameter schemas for the usecase, test, presentation-feature, and asset bricks. Split
out of `bricks.md` (the index). **Read `bricks.md` first** — the critical naming rules and the
mandatory two-step procedure live there and apply to every brick below. Brick numbers kept stable
(§5–§11).

Feature / repository / page / entity scaffolding bricks (§1–§4) are in
`docs/bricks-reference-scaffolding.md`.

---

## 5. `new_usecase` (standalone)

Use when adding a **no-parameter usecase** to an existing feature.

When `entity_name` is provided, generates a **fully wired** usecase that injects the repository and
delegates to `repository.{repository_method_name}()`. When `entity_name` is empty (default),
generates a **stub** with `throw UnimplementedError()`.

> ⚠️ When invoked standalone, the agent **must** also run `mason make new_usecase_test` afterwards
> (see §7).

```bash
# Step 1 – write the config file (stub mode)
cat > /tmp/usecase_vars.json << 'EOF'
{
  "feature_name":     "users",
  "usecase_name":     "GetAllUserUseCase",
  "return_type_name": "List<User>"
}
EOF

# Step 1 – write the config file (wired mode, when called from new_repository)
cat > /tmp/usecase_vars.json << 'EOF'
{
  "feature_name":           "users",
  "usecase_name":           "GetAllUserUseCase",
  "return_type_name":       "List<User>",
  "entity_name":            "User",
  "repository_method_name": "getAll"
}
EOF

# Step 2 – run the brick
mason make new_usecase \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/usecase_vars.json
```

### Variable reference

| Variable                 | Type   | Required | Description                                        |
|--------------------------|--------|----------|----------------------------------------------------|
| `feature_name`           | string | ✅        | Feature folder name (snake_case)                   |
| `usecase_name`           | string | ✅        | Full class name with "UseCase" suffix (PascalCase) |
| `return_type_name`       | string | ✅        | Dart return type (e.g. `"List<User>"`)             |
| `entity_name`            | string | ❌        | Entity name (PascalCase). Enables wired mode.      |
| `repository_method_name` | string | ❌        | Repository method to delegate to (camelCase)       |

---


## 6. `new_usecase_with_request` (standalone)

Use when adding a **parameterised usecase** to an existing feature.

When `entity_name` is provided, generates a **fully wired** usecase that injects the repository and
delegates to `repository.{repository_method_name}()`, unpacking request fields as arguments.
When `entity_name` is empty (default), generates a **stub** with `throw UnimplementedError()`.

> ⚠️ When invoked standalone, the agent **must** also run `mason make new_usecase_test` afterwards
> (see §7).

```bash
# Step 1 – write the config file (stub mode)
cat > /tmp/usecase_req_vars.json << 'EOF'
{
  "feature_name":      "users",
  "usecase_name":      "GetByIdUserUseCase",
  "return_type_name":  "User",
  "request_type_name": "GetByIdUserRequest",
  "request_fields": [
    { "name": "id", "type": "int" }
  ]
}
EOF

# Step 1 – write the config file (wired mode)
cat > /tmp/usecase_req_vars.json << 'EOF'
{
  "feature_name":           "users",
  "usecase_name":           "GetByIdUserUseCase",
  "return_type_name":       "User",
  "request_type_name":      "GetByIdUserRequest",
  "request_fields":         [{ "name": "id", "type": "int" }],
  "entity_name":            "User",
  "repository_method_name": "getById"
}
EOF

# Step 2 – run the brick
mason make new_usecase_with_request \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/usecase_req_vars.json
```

### Variable reference

| Variable                 | Type   | Required | Description                                              |
|--------------------------|--------|----------|----------------------------------------------------------|
| `feature_name`           | string | ✅        | Feature folder name (snake_case)                         |
| `usecase_name`           | string | ✅        | Full class name with "UseCase" suffix (PascalCase)       |
| `return_type_name`       | string | ✅        | Dart return type (e.g. `"User"`)                         |
| `request_type_name`      | string | ✅        | Request class name (PascalCase, e.g. `"GetByIdRequest"`) |
| `request_fields`         | list   | ✅        | Fields of the request object `[{name, type}]`            |
| `entity_name`            | string | ❌        | Entity name (PascalCase). Enables wired mode.            |
| `repository_method_name` | string | ❌        | Repository method to delegate to (camelCase)             |

---

## Usecase naming convention

The `new_repository` brick (and by extension `feature_complete`) auto-generates usecase class names
following this rule:

```
{method.name.PascalCase}{EntityName.PascalCase}UseCase
```

The `usecase_name` variable **must include the "UseCase" suffix** (e.g. `"GetAllUserUseCase"`).
Each usecase is placed in its own directory named with the full snake_case of the class:

```
domain/usecases/{usecase_name_snake_case}/{usecase_name_snake_case}.dart
```

Examples (for entity `User`):

| Method name | Generated usecase class | Directory & file                                       |
|-------------|-------------------------|--------------------------------------------------------|
| `getAll`    | `GetAllUserUseCase`     | `get_all_user_use_case/get_all_user_use_case.dart`     |
| `getById`   | `GetByIdUserUseCase`    | `get_by_id_user_use_case/get_by_id_user_use_case.dart` |
| `create`    | `CreateUserUseCase`     | `create_user_use_case/create_user_use_case.dart`       |
| `delete`    | `DeleteUserUseCase`     | `delete_user_use_case/delete_user_use_case.dart`       |

Use these exact class names in the `usecases` list of each `pages` entry.

---

## 7. `new_usecase_test` (standalone + auto-chained)

Generates a unit test for a usecase. Mocks the repository with `mocktail` and tests both
`DataSuccess` and `DataFailed` paths.

**Auto-chained by:** `new_repository` (and by extension `feature_complete`).
When invoked standalone (after `new_usecase` or `new_usecase_with_request`), the agent must call
this brick manually.

```bash
# Step 1 – write the config file
cat > /tmp/usecase_test_vars.json << 'EOF'
{
  "feature_name":           "users",
  "entity_name":            "User",
  "usecase_name":           "GetAllUserUseCase",
  "return_type_name":       "List<User>",
  "repository_method_name": "getAll",
  "has_param":              false,
  "param_name":             "",
  "param_type":             ""
}
EOF

# Step 2 – run the brick
mason make new_usecase_test \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/usecase_test_vars.json
```

### Variable reference

| Variable                 | Type    | Required | Description                                               |
|--------------------------|---------|----------|-----------------------------------------------------------|
| `feature_name`           | string  | ✅        | Feature folder name (snake_case)                          |
| `entity_name`            | string  | ✅        | Entity class name (PascalCase)                            |
| `usecase_name`           | string  | ✅        | Full usecase class name with "UseCase" suffix             |
| `return_type_name`       | string  | ✅        | Dart return type (e.g. `"List<User>"`)                    |
| `repository_method_name` | string  | ❌        | Repository method name (camelCase). Auto-derived if empty |
| `has_param`              | boolean | ❌        | Whether the usecase takes a parameter. Default: `false`   |
| `param_name`             | string  | ❌        | Parameter name (when `has_param=true`)                    |
| `param_type`             | string  | ❌        | Parameter type (when `has_param=true`)                    |

---

## 8. `new_repository_test` (standalone + auto-chained)

Generates a unit test for a `RepositoryImpl`. Mocks the `LocalDatasource` with `mocktail` and
tests each method for `DataSuccess` on success and `DataFailed` when the datasource throws.

**Auto-chained by:** `new_repository` (and by extension `feature_complete`).

```bash
# Step 1 – write the config file
cat > /tmp/repo_test_vars.json << 'EOF'
{
  "feature_name": "users",
  "entity_name":  "User",
  "methods": [
    {
      "name": "getAll", "return_type": "List<User>",
      "has_param": false, "param_name": "", "param_type": ""
    },
    {
      "name": "getById", "return_type": "User",
      "has_param": true, "param_name": "id", "param_type": "int"
    }
  ]
}
EOF

# Step 2 – run the brick
mason make new_repository_test \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/repo_test_vars.json
```

### Variable reference

| Variable       | Type   | Required | Description                                  |
|----------------|--------|----------|----------------------------------------------|
| `feature_name` | string | ✅        | Feature folder name (snake_case)             |
| `entity_name`  | string | ✅        | Entity class name (PascalCase)               |
| `methods`      | list   | ✅        | Same schema as `new_repository` methods list |

---

## 9. `new_bloc_test` (standalone + auto-chained)

Generates a test file for a BLoC using `flutter_test` + `mocktail`. Mocks each injected usecase,
tests the `Started` event, and scaffolds commented-out test stubs for each custom event.
Does **not** use `bloc_test` package (incompatible with `floor_generator`).

**Auto-chained by:** `new_page` (and by extension `feature_complete`).

```bash
# Step 1 – write the config file
cat > /tmp/bloc_test_vars.json << 'EOF'
{
  "feature_name": "users",
  "entity_name":  "User",
  "page_name":    "UsersList",
  "bloc_name":    "UsersList",
  "bloc_events":  ["LoadUsersEvent"],
  "usecases":     ["GetAllUserUseCase"]
}
EOF

# Step 2 – run the brick
mason make new_bloc_test \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/bloc_test_vars.json
```

### Variable reference

| Variable       | Type   | Required | Description                                                  |
|----------------|--------|----------|--------------------------------------------------------------|
| `feature_name` | string | ✅        | Feature folder name (snake_case)                             |
| `entity_name`  | string | ✅        | Entity class name (PascalCase)                               |
| `page_name`    | string | ✅        | Page name (PascalCase)                                       |
| `bloc_name`    | string | ✅        | BLoC name (PascalCase)                                       |
| `bloc_events`  | list   | ❌        | Additional event name strings. Default: `[]`                 |
| `usecases`     | list   | ❌        | Usecase class names to inject (e.g. `["GetAllUserUseCase"]`) |

---

## 10. `sync_app_images`

Scans the `assets/` folder at the project root, groups image files by their immediate subfolder,
and **overwrites** `lib/theme/token/light_app_images.dart` with a generated `LightAppImages` class.

**No user vars** — everything is derived from the filesystem at generation time.
**Always run with `--on-conflict overwrite`** (the file is always fully regenerated).

### What it generates

- One private inner class per subfolder (e.g. `assets/icons/` → `_IconImages`), with one
  `static const String` field per image file (camelCase filename without extension).
- `LightAppImages extends AppImages` with a `const` constructor and one `final` field per
  subfolder of type `_SubfolderImages`.
- Files directly under `assets/` (no subfolder) go into a `_RootImages` class exposed as
  `final _RootImages root`.
- Supported extensions: `.png` `.jpg` `.jpeg` `.gif` `.svg` `.webp` `.bmp` `.ico`.
- `// ignore_for_file: library_private_types_in_public_api, unused_field` is added automatically.
- `post_gen` hook runs `dart format` on the generated file.

### Invocation

```bash
# Step 1 – write an empty config (brick takes no vars)
echo '{}' > /tmp/sync_app_images_vars.json

# Step 2 – run the brick (always overwrite)
~/.pub-cache/bin/mason make sync_app_images \
  --output-dir . \
  --on-conflict overwrite \
  --config-path /tmp/sync_app_images_vars.json
```

> ⚠️ `mason` may not be on `$PATH`. Use `~/.pub-cache/bin/mason` if the bare `mason` command
> is not found.

### Variable reference

This brick takes **no input variables**. The hook reads `assets/` from `Directory.current.path`
(i.e. the project root when `--output-dir .` is used).

### Generated file

`lib/theme/token/light_app_images.dart` — always overwritten, never manually edited.

### When to run

Run whenever images are added to, removed from, or renamed inside `assets/`.

---

## 11. `presentation_feature`

Use when creating a **presentation-only feature** — one that has UI and BLoC but no entity or
repository of its own. Data operations are delegated to other features via use case injection at
the route level.

### Full two-step invocation example

```bash
# Step 1 – write the config file
cat > /tmp/cash_register_vars.json << 'EOF'
{
  "feature_name": "cash_register",
  "pages": [
    {
      "page_name": "CashRegister",
      "bloc_name": "CashRegister",
      "bloc_events": ["AddItemToCashRegisterEvent", "RemoveItemEvent", "CompleteSaleEvent"],
      "usecases": ["GetAllItemUseCase", "CreateSaleUseCase", "CreateSaleItemUseCase"],
      "path": "/cash-register"
    }
  ]
}
EOF

# Step 2 – run the brick
mason make presentation_feature \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/cash_register_vars.json
```

### Variable reference

| Variable       | Type   | Description                                                                                 |
|----------------|--------|---------------------------------------------------------------------------------------------|
| `feature_name` | string | Feature folder name — **plural snake_case** (e.g. `"cash_register"`)                       |
| `pages`        | list   | Pages/BLoC pairs. Same schema as `feature_complete` pages, but `usecases` refers to use cases from **other features**. |

### Generated files

- `presentation/navigation/{feature}_destinations.dart`
- `presentation/navigation/{feature}_route_provider.dart` — contains `providers: const []` with a TODO comment
- For each page: bloc, event, state, page UI, bloc test (via `new_page`)

### After generation

1. Open `{feature}_route_provider.dart` and replace `providers: const []` with the cross-feature
   providers needed, e.g.:
   ```dart
   providers: [...itemProviders(), ...saleProviders()],
   ```
2. Register the route in `lib/core/navigation/router.dart`.
