---
name: new-feature
description: Use BEFORE creating any new feature, file, or class under lib/features/ — the read-docs-first + correct-layer + mason-first orchestration. Stops the "weaker model skips the router table and violates conventions" failure. Trigger on "new feature", "new file", "add a page/entity/repo", "create class", "where does X go".
---

# new-feature

Orchestrator. Reads the right docs, places code in the right layer, delegates generation to a brick. **Does not duplicate convention detail — it routes to it.**

## Step 0 — Read before writing (mandatory)

| Touching | Read first |
|----------|-----------|
| New feature / new file | `docs/architecture/layers.md` + `docs/conventions/architecture.md` + `docs/conventions/mason.md` |
| Entity / usecase / exception | `docs/conventions/domain.md` + `docs/architecture/use-cases.md` |
| Data layer (repo, datasource, model, DAO) | `docs/conventions/data.md` |
| BLoC | `docs/architecture/bloc-rules.md` + `docs/architecture/bloc-state-patterns.md` |
| Widget / page | `docs/conventions/presentation.md` + `docs/conventions/presentation-design-system.md` + `docs/conventions/code-quality.md` |
| Route / navigation | `docs/conventions/presentation-navigation.md` |

Weaker models that skip this produce rejected code. Read the matching file, no exceptions.

## Step 1 — Layer placement

```
lib/features/{feature}/
├── domain/        # pure Dart — entities, usecases, repo interfaces, exceptions. NO flutter/floor/bloc imports
├── data/          # repo impls, datasources, DAOs, models, Floor, JSON
└── presentation/  # BLoCs, pages, widgets, navigation, design system
```

Dependency: `presentation ─► domain ◄─ data`. domain knows nothing of the others; data and presentation never import each other.

## Step 2 — Generate via brick, never by hand → use the `mason-brick` skill

If it maps to a brick (it usually does), the brick makes it. Pick:
- whole feature → `feature_complete`
- presentation-only feature (no entity/repo) → `presentation_feature`
- entity+repo in existing feature → `new_repository`
- page+bloc → `new_page`
- standalone bloc (no page) → `new_bloc`
- usecase → `new_usecase` / `new_usecase_with_request`

Canonical brick index: `docs/bricks.md` + the `mason-brick` skill table (kept in sync with
`mason.yaml` by `tool/check_conventions.sh` C8).

No brick fits + structural → STOP, ask user. Pre-approved manual only: feature exceptions, feature/core extensions.

## Step 3 — Top bans to not trip (full list: CLAUDE.md §1)

- domain: NO flutter / floor / bloc / l10n imports.
- business logic only in UseCases — not BLoCs, not repos, not widgets.
- entities rich: invariants in constructors, value objects (Money/Quantity/Email…) for constrained concepts, no bare double/int for money.
- enums for statuses, `DateTime` for domain time — never string literals across layers.
- BLoC: sealed states, one `on<Event>` per event, no shadow state, emit typed `Exception` (widget translates).
- presentation: `App*` widgets only, `context.theme.*` colors, `l10n` strings, no cross-feature presentation imports.
- English-only identifiers and comments.

## Step 4 — Verify → use the `verify-flutter` skill

analyzeFiles (no paths) clean + tests green + app-run for UI/schema changes.
