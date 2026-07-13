# Mason Bricks – Invocation Reference

> Read this file before any `mason make` invocation.
> Always pass variables via `--config-path <json-file>` to avoid interactive prompts.

## 🚨 Critical naming rules (every brick)

| Variable        | Form                          | Examples                                 |
|-----------------|-------------------------------|------------------------------------------|
| `feature_name`  | **plural** snake_case         | `customers`, `items`, `sales`            |
| `entity_name`   | **singular** PascalCase       | `Customer`, `Item`, `Sale`               |
| Usecase classes (in `usecases` page list) | `{Method.Pascal}{EntitySingular.Pascal}UseCase` | `GetAllCustomerUseCase`, `GetByIdItemUseCase`, `CreateSaleUseCase` — **never** `GetAllCustomersUseCase` |
| Request class   | `{Method.Pascal}{EntitySingular.Pascal}Request` | `GetByIdCustomerRequest` |
| `page_name` / `bloc_name` | PascalCase, distinct per page | `CustomersList`, `CustomerDetail`, `CustomerEdit` |
| Event classes (filled in by agent post-gen) | `{Action.Pascal}{BlocName.Pascal}Event` | `StartedCustomerDetailEvent`, `SaveCustomerEditEvent` |

The folder is plural; everything class-level is singular. Mixing them generates a working
project that nevertheless looks wrong everywhere.

---

## ⚠️ MANDATORY TWO-STEP PROCEDURE (agents must always follow this)

`--config-path` expects a file that **already exists on disk**. Mason does NOT create it.
You must write the JSON file yourself **before** calling `mason make`.

**Step 1 – Write the JSON config to disk:**

```bash
cat > /tmp/my_feature_vars.json << 'EOF'
{
  "feature_name": "...",
  ...
}
EOF
```

**Step 2 – Run the brick:**

```bash
mason make feature_complete \
  --output-dir . \
  --on-conflict skip \
  --config-path /tmp/my_feature_vars.json
```

Skipping Step 1 will cause:
`PathNotFoundException: Cannot open file, path = '/tmp/my_feature_vars.json'`

---

## Brick index — per-brick parameter schemas

The per-brick invocation examples and variable schemas live in two reference files. **Read the
matching one before any `mason make`** (the naming rules and two-step procedure above apply to
every brick):

### `docs/bricks-reference-scaffolding.md` — feature / repo / page / entity

| # | Brick | Use for |
|---|-------|---------|
| 1 | `feature_complete` ⭐ | Whole new feature from scratch (entity + repo + pages) |
| 2 | `new_repository` | New entity + repository in an existing feature |
| 3 | `new_page` | New page + BLoC in an existing feature (BLoC delegated to `new_bloc`) |
| 3b | `new_bloc` | Standalone BLoC (bloc + event + state) in an existing feature, no page. Also composed by `new_page` |
| 4 | `new_entity` | Entity + Floor model + DAO only (incl. rich/typed entities R5+R6) |

### `docs/bricks-reference-usecases.md` — usecase / test / presentation / asset

| # | Brick | Use for |
|---|-------|---------|
| 5 | `new_usecase` | No-parameter usecase |
| 6 | `new_usecase_with_request` | Parameterised usecase |
| — | Usecase naming convention | `{Method}{Entity}UseCase` rule + directory layout |
| 7 | `new_usecase_test` | Unit test for a usecase (auto-chained by `new_repository`) |
| 8 | `new_repository_test` | Unit test for a `RepositoryImpl` (auto-chained) |
| 9 | `new_bloc_test` | Test for a BLoC (auto-chained by `new_page`) |
| 10 | `sync_app_images` | Regenerate `LightAppImages` from `assets/` |
| 11 | `presentation_feature` | Presentation-only feature (UI + BLoC, no entity/repo) |
