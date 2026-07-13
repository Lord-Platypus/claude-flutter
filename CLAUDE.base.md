# CLAUDE.base.md

> **Base router (claude-flutter).** Generic Flutter clean-architecture rules,
> shared across projects via submodule. Project-specific overrides + the l10n
> regen command live in the consuming project's own CLAUDE.md, which `@import`s
> this file. Do not add project-specific paths here.

Lean router for Claude Code. Detailed rules live under `docs/conventions/` — **read the
matching file before touching code in that layer**.

---

## 0. What To Read Before Doing What

Match your task to the doc and **read it before writing code**. Weaker models that skip this
step produce code that violates conventions and gets rejected.

| Doing this…                                       | Read this **first**                                                                                |
|---------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Creating a new feature / file                     | `docs/architecture/layers.md` + `docs/conventions/architecture.md` + `docs/conventions/mason.md`   |
| Editing a UI widget or page                       | `docs/conventions/presentation.md` + `docs/conventions/presentation-design-system.md` + `docs/conventions/code-quality.md` |
| Editing a form / validator / input → entity build | `docs/conventions/forms-and-validation.md`                                                         |
| Editing a BLoC                                    | `docs/architecture/bloc-rules.md` + `docs/architecture/bloc-state-patterns.md` + `docs/conventions/presentation.md`        |
| Adding / changing business logic                  | `docs/architecture/use-cases.md` + `docs/conventions/domain.md`                                    |
| Touching `DataState<T>` or error states           | `docs/architecture/bloc-rules.md` §2 + `docs/conventions/domain.md` §7                             |
| Editing routes / navigation                       | `docs/conventions/presentation-navigation.md` (§4)                                                 |
| Editing data layer (repos, datasources, models)   | `docs/conventions/data.md`                                                                         |
| Editing domain (entities, usecases, exceptions)   | `docs/conventions/domain.md` + `docs/architecture/use-cases.md`                                    |
| Writing / fixing tests                            | `docs/conventions/testing.md`                                                                      |
| Naming any class, file, folder                    | `docs/conventions/architecture.md` (§4)                                                            |
| Running mason                                     | `docs/conventions/mason.md` + `docs/bricks.md`                                                     |
| Touching `bricks/` or `*.g.dart`                  | `docs/conventions/mason.md` (§3–4)                                                                 |
| Floor schema / migration change                   | `docs/conventions/data.md` (§3) — app run is mandatory                                             |

Additional references (older but still valid):

| File                               | When to read                                                 |
|------------------------------------|--------------------------------------------------------------|
| `docs/project.md`                  | Project overview, tech stack, dependencies                   |
| `docs/bricks.md`                   | Brick parameter schemas — mandatory before any `mason make`  |
| `docs/architecture/templates.md`   | Gold-standard code templates                                 |

---

## 1. Zero-Tolerance Bans (no detail — see referenced doc for examples)

These bans apply **everywhere** and are repeated inline so you cannot miss them. If a rule
sounds restrictive, read the referenced doc — every ban has a worked example showing the
forbidden pattern and its replacement.

- **NO** Flutter or Floor imports in `domain/`. → `domain.md`, `docs/architecture/layers.md` §2
- **NO** business logic in BLoCs or Repositories — only in **UseCases**. → `domain.md` §3,
  `docs/architecture/use-cases.md`
- **NO** identity assignment, timestamp stamping, or create-vs-update decisions inside
  BLoCs. Those are use case responsibilities. → `docs/architecture/bloc-rules.md` §3
  (Violation 2)
- **NO** decision/mode logic in UI widgets (sentinel checks, mode flags, conditional flows).
  Bloc decides; UI renders. → `presentation.md` §2
- **NO** `AppLocalizations` / `l10n` inside BLoCs. BLoCs emit typed `Exception`. Widgets
  translate via `context.appLocalization.translateException(state.exception)`.
  → `docs/architecture/bloc-rules.md` §1 (Violation 1)
- **NO** `?? fallback` after `result.exception` — `DataFailed.exception` is non-null by
  construction. The fallback branch is dead code. Use pattern matching.
  → `docs/architecture/bloc-rules.md` §2
- **NO** hardcoded user-facing strings in widgets. All user copy via `l10n`.
  → `presentation.md` §1
- **NO** sentinel-string parameters between layers (e.g. `customerId: 'new'`). Use typed
  nullables (`int? customerId`, `null` = create). → `presentation-navigation.md` §4
- **NO** string-literal route paths or `.replaceFirst(':id', ...)` hacks. Use `pushNamed`
  with `pathParameters` and the destinations enum's `name`. → `presentation-navigation.md` §4
- **NO** feature routes at the top level of `AppRouter`. Every page is a branch (or child
  route) of the single `dashboardRouteProvider()` shell so the sidebar is always visible.
  → `presentation-navigation.md` §4
- **NO** raw `ElevatedButton` / `FilledButton` / `OutlinedButton` / `TextButton` / `Card` /
  etc. inside a feature. Use the corresponding `App*` widget. Extend the design system if
  missing. → `presentation-design-system.md` §5
- **NO** inline colours or `const Color(0x...)` inside features. All visual values via
  `context.theme.*`. → `presentation-design-system.md` §6
- **NO** invoking a use case from the presentation/UI layer (widgets, dialogs,
  `onTap`/`onPressed`, `FutureBuilder`/`load:` callbacks). UI dispatches an **event**; the BLoC
  calls the use case and emits state. The *only* use-case reference allowed in a widget is wiring
  one into a BLoC constructor inside `BlocProvider`'s `create:`. → `presentation.md` §2.1,
  `bloc-rules.md` §11
- **NO** referencing a BLoC outside the page that owns its `BlocProvider`. Sub-widgets/dialogs
  take plain data via constructor and report intent via **callbacks** — never
  `BlocBuilder`/`context.read<XBloc>`/`bloc.add(...)`. The page maps state → child props and turns
  child callbacks into events. ("Page" = the `BlocProvider` owner, even a `*_tab`.)
  → `presentation.md` §2.2
- **NO** direct DB access from BLoCs. **NO** bypassing the Repository layer.
- **NO** enum-based BLoC states — sealed classes only.
- **NO** `get_it` / service locator. Provider / ProxyProvider only. → `architecture.md` §3
- **NO** manually creating files that a Mason brick can generate. → `mason.md` §1
- **NO** `dart format .` / `dart format bricks/` — corrupts brick templates.
  → `mason.md` §3
- **NO** shadow state — mutable private `_field` accumulators in a BLoC that duplicate the
  emitted state and get rebuilt on every emit. State is the single source of truth; read
  prior values from `state`, emit derived state via `copyWith`.
  → `docs/architecture/bloc-state-patterns.md` §7
- **NO** transient outcomes as nullable fields on a success state (`Exception? saleError`).
  A one-shot result is its own distinct state. → `docs/architecture/bloc-state-patterns.md` §8
- **NO** business logic or domain invariants in the presentation layer. Derivations (date
  filtering, aggregations) and invariants (clamping cart qty to stock) live in use cases /
  domain. (`DateTime.now()` for display/UX defaults — e.g. a date-picker's initial date — is
  allowed in widgets.) → `docs/architecture/bloc-rules.md` §3, `presentation.md` §2
- **NO** cross-feature presentation imports. A feature's `presentation/` must never import
  another feature's `presentation/` (extensions, widgets, blocs). Features communicate only
  through the domain layer. → `architecture.md` §1, `docs/architecture/layers.md` §4
- **NO** anemic entities. Entities own their invariants and behaviour: validate in
  named/factory constructors, expose intent-revealing methods, no public unguarded setters,
  value objects for constrained concepts. → `domain.md` §2
- **NO** string literals for typed domain concepts. Statuses are enums (never
  `status = 'COMPLETATA'`); domain time is `DateTime` (`occurredAt` is `DateTime`, not
  `String`) — convert to/from string only at the data/mapping boundary. → `domain.md` §8
- **NO** non-English identifiers, types, or comments. Code is English-only — no Italian
  (`CassaProductTile`, `numero`). Rename consistently across the codebase. → `code-quality.md` §9
- **NO** single `_onEvent` dispatcher that `switch`es over events in a BLoC. One
  `on<SpecificEvent>(_handler)` per event (brick style). → `bloc-rules.md` §9
- **NO** `switch` over `DataState`, and **NO** redundant `else if (result is DataFailed)`.
  Plain `else`, or guard-and-return. → `bloc-rules.md` §10
- **NO** work (an `await`, call, or ternary) buried inside constructor/method call arguments.
  Compute, name a variable, then pass it. → `code-quality.md` §10
- **NO** premature abstraction for short handlers (generic `_reemit`-style helpers). Repeat
  the few lines. → `code-quality.md` §11
- **NO** unblocked method bodies — blank line before `if`/`for`/`while`/`return`/`emit` and
  after a control body. → `code-quality.md` §12
- **NO** `.then(...)` — always `async`/`await`. → `code-quality.md` §13
- **NO** free helper functions at the top of a widget file, or helpers above `build`. Private
  helpers/handlers/mappers go at the **bottom** of the class. → `presentation-design-system.md` §12
- **NO** bare `double`/`int`/`String` for concepts with invariants or behavior — use value
  objects. **Every new/edited entity: check each field** (invariant? behavior? named concept? →
  VO). Not a closed list. Known VOs: Money/Quantity/Email/Phone/FiscalCode/VatNumber/ZipCode;
  money is `Money` (cents-backed, owns `format()`), never a formatted `double`. → `domain.md` §9
- **NO** user input reaching a throwing entity/VO constructor without the form validating the
  same invariant first. Out-of-range input shows **inline at the field**, never only in a log.
  `ArgumentError` from a constructor = programmer error, not a user-facing channel. Validator and
  constructor share one invariant definition. → `forms-and-validation.md` §2

---

## 2. Quick Commands

### Build & Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d linux
dart format lib/ test/    # NEVER format bricks/ or *.g.dart files

# Regenerate localizations after editing your ARB files.
# `flutter gen-l10n` with no args FAILS if l10n.yaml is not at project root —
# pass the flags explicitly. Exact ARB paths are project-specific: see the
# consuming project's CLAUDE.md (l10n section).
```

### Testing

```bash
flutter test
flutter test test/features/<feature_name>/
flutter test test/features/<feature_name>/domain/usecases/<usecase>/<usecase>_usecase_test.dart
```

### Mason (two-step mandatory)

```bash
cat > /tmp/<name>_vars.json << 'EOF'
{ ... }
EOF
mason make <brick> --output-dir . --on-conflict skip --config-path /tmp/<name>_vars.json
```

Full mandatory workflow: `mason.md` §2.

### Deterministic convention check

`tool/check_conventions.sh` (run automatically by the Stop verify-gate on changed files;
`--all` scans whole `lib/`) enforces the greppable §1 bans: layer dependency direction
(presentation → domain ← data, domain pure), raw widgets that have an `App*` design-system
twin (list derived live from `app_design_system/widgets/`), inline colours, l10n-in-bloc,
cross-feature presentation imports, `.then(`, route-string hacks, and mason-reference drift
(every `mason.yaml` brick referenced in `docs/bricks.md` + mason skill/agent tables).
Script failing = fix before done. Judgment bans still need the ban-by-ban gate / auditor.

### ⛔ Forbidden Bash Commands

| Forbidden                                                    | Use instead                                                                          |
|--------------------------------------------------------------|--------------------------------------------------------------------------------------|
| `flutter analyze` (any variant)                              | Dart MCP `analyzeFiles` with no `paths` arg (see §3)                                 |
| `dart format .` / `flutter format .` / `dart format bricks/` | `dart format lib/ test/` only. Wider scope corrupts `bricks/`                        |
| Manual creation of files a Mason brick generates             | The brick. See `mason.md` §1                                                         |
| `flutter pub run build_runner watch`                         | Re-run `dart run build_runner build --delete-conflicting-outputs`. Watch masks errors |

---

## 3. Dart MCP Server (verification)

After creating or editing any Dart/Flutter file:

1. Call `analyzeFiles` with **no `paths`** (full project scan). Never scope to only the
   modified files — shared abstractions cause cascade errors that narrow scans miss. Fix all
   errors/warnings before declaring done.
2. Call `runTests` if touching logic covered by tests.

---

## 4. Agent Behaviour Policies

- **Dependencies:** Do not add new packages to `pubspec.yaml` without proposing them first.
- **Refactoring:** Suggest improvements, but do not change the core architecture folder
  structure.
- **Scope:** Stick to the feature requested; do not modify unrelated features.
- **Wrong spec → report, don't silently work around:** If a spec/plan under
  `docs/superpowers/specs/` (or any instruction) states something **false** — a brick that does
  not exist, a wrong file path, an impossible sequencing, a stale assumption — **stop and report
  it to the user so the spec can be fixed.** Do not just route around it silently. Fixing the
  code without fixing the spec leaves the next session to re-hit the same wrong instruction.
- **Brick-first for common artifacts — propose a brick, don't hand-roll:** Bricks have
  **priority** over hand-writing. The §1 ban already forbids hand-creating what a brick *can*
  generate. Extension: when you must hand-create something **common** to building this app (a
  BLoC, a feature, a repository, a page, a usecase, an entity, a datasource, a model) and **no
  brick covers it**, do not just hand-roll and move on — **propose creating a Mason brick** for
  it first (per `mason.md`; propose, never create silently). Only hand-write after the user
  declines the brick or for genuinely one-off, non-repeating structures. (`new_bloc` and
  `presentation_feature` exist now — full index in `mason.yaml` / `docs/bricks.md`, kept in
  sync by `tool/check_conventions.sh` C8.)
- **Always verify before declaring done:** Run `analyzeFiles` (no `paths`). Fix all
  errors/warnings, then verify once more. If the same error persists after one fix attempt,
  **stop and report to the user** — do not loop.
- **Convention-compliance gate (before declaring done):** `analyzeFiles` and tests are the
  *compile/behavior* gate. Conventions are a **separate, mandatory gate.** Before "done",
  re-open every `docs/conventions/` file from the §0 router table matching the layer you
  touched, and check your diff **ban-by-ban**, naming each rule you verified. If your change
  introduces a pattern, file location, or abstraction **not already shown in that doc**, treat
  it as a probable violation: stop and flag to the user — never self-approve a novel pattern.
- **Coherence sweep (before changing any pattern):** When asked to add, move, rename, or
  re-home a pattern (validator, helper, widget, naming, location), first `grep` the whole
  codebase for every existing instance of that concept. Either bring them **all** into line in
  the same change, or — if out of scope — enumerate them and **schedule** a refactor (spec
  file). Report the full sibling list. Never fix one and silently leave the rest.
  **Sweep the whole layer, never pre-filter by subfolder.** Grep all of `presentation/` (or
  `domain/`, `data/`), not just `ui/` — exclude only the provably-safe (e.g. `bloc/` when hunting
  UI-side calls). Classify *after* the full grep. (A narrowed `ui/`-only sweep once missed
  `navigation/` + `core/` — they happened to be compliant, but the miss was luck, not method.)
- **Remove spec/plan files when done:** After fully implementing a spec or plan from
  `docs/superpowers/specs/`, delete the file. The code and git history are the source of
  truth; spec files left behind become stale and misleading.
- **Mistake → root-cause + rule update:** When you make a mistake (a miss, a wrong assumption, a
  rejected change, a re-do), don't just fix it — **diagnose *why* it happened** and **propose a
  rule/doc/skill update** that would prevent the whole class of mistake recurring. Cite the
  concrete failure. If an existing rule already covered it, the fix is a method tweak that makes
  the rule harder to skip, not a duplicate rule. Apply the fix in the same session where feasible.
- **End-of-task read-permission audit:** At the end of every task, check whether you prompted the
  user for any **read-only** access inside the project folder (a `Bash` read like
  `grep`/`find`/`sed -n`/`awk`/`wc`/`ls`/`cat`, or a read tool). If so, **propose a standing fix**
  so it never prompts again — the goal is **zero read-permission prompts inside the project**.
  Preferred fixes, in order: (1) use the dedicated **Read/Grep/Glob tools** (allowlistable
  whole-tool, never prompt) instead of bash for reads; (2) keep any bash read **atomic** (one
  command, no `for`/`$()`/`&&`/pipes — compound blobs don't match the allowlist, see
  `[[feedback_atomic_bash_for_allowlist]]`); (3) add a **broad** `Bash(<cmd>:*)` allow entry
  (grep/find/wc/ls/cat/sed/awk/head/tail/rg) via the `update-config` skill — never one-off
  per-invocation entries. Offer to apply the fix; don't silently accumulate one-offs.
- **Tests are not enough:** Tests prove code correctness, not feature correctness. For UI
  changes and Floor schema changes, **launch the app** (`flutter run -d linux`) and exercise
  the feature manually before declaring done. See `testing.md` §8.
- **Rendering ≠ working — check every element you create:** A widget showing up in the tree, a
  screenshot, or `get_widget_tree` only proves it was built, never that it functions. Before
  declaring done, **interact with every element you added**: open dropdowns and confirm they
  have options then select one, tap buttons and confirm the effect, submit forms, confirm
  lists show real rows. Data-driven widgets (dropdowns, lists) are only verified when their
  table actually has rows — a control bound to an empty/un-seeded table is broken on a fresh
  install even with all tests green. See `testing.md` §8.1–8.2.
- **Propose docs refactors periodically:** When you notice the convention docs under
  `docs/conventions/` are getting stale, redundant, contradictory, or missing rules for
  patterns you encounter often — **propose a docs refactor to the user**. Be specific:
  cite files and sections. The user will switch to a stronger model to execute the refactor.
  Do NOT refactor docs yourself unless explicitly asked.
- **Keep convention/instruction docs short:** target **≤ 400 lines**, hard cap **~500** (mirrors
  the widget-code rule, `presentation-design-system.md` §7). A doc past the cap should be split by
  sub-topic into its own file and linked from the `§0` router. When an edit would push a doc over
  the cap, **flag it and propose the split** rather than growing it further. (The 2026-06-23
  offenders — `presentation.md`, `bricks.md`, `bloc-rules.md` — were split; all docs now ≤ ~500.)

### Delegation — when to spawn a subagent vs work inline

Subagents cold-start and re-derive context, so delegate only where it pays: read-heavy work
with a small answer (context compression), a fixed checklist/gate that gets skipped as prose,
or independent/parallel work. Every spawn brief must include: scope (file:line or layers),
which doc to read, and a hard scope cap ("refuse if > N files"). Keep judgment calls, Floor
migrations, and live app-run smokes on the main thread.

| Task | Delegate to |
|---|---|
| Locate code / map a dir / "where is X / what calls Y" | `cavecrew-investigator` |
| Sibling sweep before a pattern change (coherence gate) | `cavecrew-investigator` |
| Diff / PR / branch review | `cavecrew-reviewer` |
| Pre-"done" convention ban check (compliance gate) | `convention-compliance-auditor` |
| Bounded 1–2 file mechanical edit (rename, typo, single fn) | `cavecrew-builder` |
| Judgment, new-feature design, Floor migration, app-run verify | inline (main thread) |

The **convention-compliance gate** and **coherence sweep** bullets above are the two mandatory
gates I most often skip as prose — prefer firing the mapped agent over relying on willpower.
`convention-compliance-auditor` is read-only and returns a ban-by-ban verdict; it does not fix.

---

## 5. Layer Map (where things live)

```
lib/
├── core/                                     # cross-cutting infrastructure
│   ├── app_design_system/widgets/            # App* widgets (mandatory inside features)
│   ├── app_design_system/theme/token/        # abstract tokens
│   ├── extensions/                           # cross-feature extensions
│   ├── localization/                         # l10n (Italian only; arbs in arbs/)
│   ├── navigation/router.dart                # AppRouter — composes feature routes
│   ├── di/injection.dart                     # global providers
│   └── utils/                                # DataState, UseCase base classes, exceptions
├── theme/token/                              # concrete light theme values
└── features/{feature}/
    ├── domain/                               # pure Dart — entities, usecases, exceptions, repos
    ├── data/                                 # models, DAOs, datasources, repository impls
    └── presentation/                         # BLoCs, pages, navigation, extensions
```

Detailed folder structure per layer: `architecture.md` §2.
