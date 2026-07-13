---
name: verify-flutter
description: Use BEFORE claiming any Flutter/Dart work is done, fixed, passing, or ready to commit. Enforces the compliance→analyze→test→app-run gate; blocks "tests green so it works", "it renders so it works", and "compiles so it's compliant" false completion. Trigger on "done", "verify", "is it working", "ready to commit", finishing a feature or fix.
---

# verify-flutter

Completion gate. Evidence before claims. **Canonical: `docs/conventions/testing.md` §8 + CLAUDE.md §3–§4.**

## Gate 0 — Convention compliance (always) — SEPARATE FROM COMPILE/TESTS

`analyzeFiles` + tests prove **compile/behavior**, NOT conventions. A change can be green and still violate the rules — this is a distinct, mandatory gate. **Canonical: CLAUDE.md §4 + §0 router table.**

1. Re-open every `docs/conventions/` file from the §0 router table matching the layer you touched.
2. Walk your diff **ban-by-ban**, naming each rule you verified — not a vibe check.
3. **Novel pattern = probable violation.** If your change introduces a pattern, file location, or abstraction **not already shown in that doc** (e.g. a new `core/` subfolder, a new helper home, a new validator shape), do not self-approve — STOP and flag to the user.

Skip nothing here because "tests pass." Tests passing is exactly when an undetected convention violation ships.

**Prefer delegating this gate:** dispatch the `convention-compliance-auditor` subagent with your diff + touched layers. It reads only the matching docs and returns a compressed ban-by-ban verdict (🔴/🟡/🟠 + `VERDICT`), so the main thread doesn't re-load every doc. It is read-only and does **not** fix — you act on its findings here. (CLAUDE.md §4 Delegation table.) Doing it inline is the fallback when no subagent is available.

## Gate 1 — Analyze (always)

Dart MCP `analyzeFiles` with **NO `paths`** (full-project scan). Never scope to changed files only — shared abstractions cascade errors a narrow scan misses. Fix every error/warning, then run once more clean.

⛔ Never `flutter analyze` (any variant). ⛔ Never `dart format .` / `dart format bricks/` — only `dart format lib/ test/`, then `git restore '*.g.dart'`.

## Gate 2 — Tests

`flutter test` (or `flutter test test/features/<f>/`). Must exit 0. Touching tested logic → `runTests` after edits.

Broken-by-structural-change test → regenerate via brick **only if purely generic**. Test carries custom assertions (VO invariants, business edges) → hand-correct or re-add them; blind regen silently deletes coverage.

## Gate 3 — App-run (UI or Floor/schema changes) — ZERO TOLERANCE

Tests prove code correctness, not feature correctness. For any UI flow or schema-touching change: **launch the app** (`flutter run -d linux` / `launch_app`) and exercise it.

**Rendering ≠ working.** A widget in the tree / screenshot / `get_widget_tree` proves it was *built*, never that it *works*. Interact with every element you added:
- buttons/taps → trigger, confirm the nav/snackbar/state change
- dropdowns/selectors → **open, confirm options exist, pick one, confirm it sticks** (empty dropdown renders fine — #1 "looks done, isn't" trap)
- forms → submit valid + invalid, confirm validation + success path
- lists → confirm rows with **real data**, not empty `ListView`

**Data-dependent widget needs data.** A control bound to an empty/un-seeded table is broken on fresh install even with all tests green. Confirm rows exist:
```bash
python3 -c "import sqlite3; print(sqlite3.connect('.dart_tool/sqflite_common_ffi/databases/volta_gestionale.db').execute('SELECT COUNT(*) FROM <table>').fetchone())"
```
Nothing seeds it + feature can't work without it → seed defaults (idempotent Floor `onOpen`) or build the management UI. Don't ship a permanently-empty control.

## Don't claim done until

convention-compliance checked ban-by-ban (no novel unsanctioned pattern) · analyze clean (no paths) · `flutter test` exits 0 · UI/schema → app launched + every new element interacted with + data-backed widgets have rows. If the same error persists after one fix attempt → STOP, report to user, no loop.
