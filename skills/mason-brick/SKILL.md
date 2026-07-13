---
name: mason-brick
description: Use BEFORE creating any feature, entity, repository, page, BLoC, or usecase, and before any `mason make` / brick work. Enforces the mason-first policy — never hand-create a file a brick can generate — and the mandatory write-json-then-make two-step. Trigger on "new feature", "new entity/repo/page/bloc/usecase", "scaffold", "mason".
---

# mason-brick

Procedure skeleton. **Canonical detail: `docs/conventions/mason.md` + `docs/bricks.md` (the brick index — it links the per-brick schema in `docs/bricks-reference-scaffolding.md` / `docs/bricks-reference-usecases.md`) — read before running anything.** This skill only guarantees the order and the two non-negotiable gates.

## Gate 1 — Mason-first (zero tolerance)

If the artifact maps to a brick, the brick MUST make it. Never hand-create.

| Want | Brick |
|------|-------|
| Whole new feature (entity+repo+pages+blocs) | `feature_complete` ⭐ |
| Entity+repo in existing feature | `new_repository` |
| Entity+Floor model+DAO only | `new_entity` |
| Page+BLoC in existing feature | `new_page` |
| Standalone BLoC, no page (also composed by new_page) | `new_bloc` |
| Presentation-only feature (pages+blocs, no entity/repo; cross-feature usecases at route level) | `presentation_feature` |
| No-param usecase | `new_usecase` |
| Param usecase (request obj) | `new_usecase_with_request` |
| Usecase / bloc / repo test | `new_usecase_test` / `new_bloc_test` / `new_repository_test` |
| Regenerate app images from assets/ | `sync_app_images` |

This table must list **every** brick in `mason.yaml` — `tool/check_conventions.sh` C8 fails
the verify gate when a brick is added/renamed without updating it.

No brick fits and artifact is structural → **STOP, ask user** (except pre-approved manual: feature exceptions, feature/core extensions — see `mason.md` §5).

## Gate 2 — Two-step, never skip

`--config-path` needs a file ALREADY on disk. Mason won't create it.

```bash
cat > /tmp/<name>_vars.json << 'EOF'
{ ... }
EOF
mason make <brick> --output-dir . --on-conflict skip --config-path /tmp/<name>_vars.json
```

Skipping step 1 → `PathNotFoundException: Cannot open file, path = '/tmp/<name>_vars.json'`.

## Naming (every brick — full table in `bricks.md`)

- `feature_name`: plural snake_case (`customers`)
- `entity_name`: singular PascalCase (`Customer`)
- usecase class: `{Method}{EntitySingular}UseCase` — `GetAllCustomerUseCase`, **never** `GetAllCustomersUseCase`

Folder plural, every class singular. Mixing = working project that looks wrong everywhere.

## Order

1. Pick brick + build JSON (read `bricks.md`, then the brick's schema in the linked reference file)
2. Write JSON to `/tmp`
3. `mason make`
4. Verify: `find lib/features/<f> -type f` + `find test/features/<f> -type f`. Missing → stop, ask user.
5. Fill stubs. DI + DB registration auto by hooks. Standalone usecase → add `ProxyProvider` manually. Floor/JSON annotations changed → `dart run build_runner build --delete-conflicting-outputs`.
6. `flutter test test/features/<f>/` until green.

## Hard bans

- ⛔ `dart format .` / `dart format bricks/` — corrupts `{{mustache}}` tags. Only `dart format lib/ test/`.
- ⛔ hand-creating a brick-able file.
- ⛔ `mason make` before the JSON file exists.
- Brick fails → STOP, report full error, wait. No manual fallback.
