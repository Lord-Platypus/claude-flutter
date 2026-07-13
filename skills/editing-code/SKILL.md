---
name: editing-code
description: Use BEFORE editing, moving, renaming, refactoring, or re-homing existing code — anything that changes an established pattern. Enforces read-the-matching-doc-first and the coherence sweep (find ALL siblings, align or schedule). Stops one-off fixes that leave the codebase incoherent. Trigger on "edit", "change", "move", "rename", "refactor", "re-home", "update this widget/bloc/validator", "fix this pattern".
---

# editing-code

Orchestrator for changing **existing** code (`new-feature` covers creation; this covers edits).
Routes to the right doc, then forces a coherence sweep so a change lands consistently across every
sibling — not as a divergent one-off. **Canonical: CLAUDE.md §0 router + §4 coherence sweep.**

## Step 1 — Read the matching doc first (mandatory)

Match the layer you're editing to the §0 router table and **re-read it before touching code** — even
for "a one-line change." The rule you're about to break is usually one you haven't read recently.

| Editing | Read first |
|---------|-----------|
| Widget / page | `docs/conventions/presentation.md` + `docs/conventions/presentation-design-system.md` + `docs/conventions/code-quality.md` |
| Route / navigation | `docs/conventions/presentation-navigation.md` |
| Form / validator / input→entity | `docs/conventions/forms-and-validation.md` |
| BLoC | `docs/architecture/bloc-rules.md` + `docs/architecture/bloc-state-patterns.md` + `docs/conventions/presentation.md` |
| Domain (entity / usecase / exception / VO) | `docs/conventions/domain.md` + `docs/architecture/use-cases.md` |
| Data (repo / datasource / model / DAO) | `docs/conventions/data.md` |
| Naming / file location | `docs/conventions/architecture.md` §4 + Layer Map (CLAUDE.md §5) |

## Step 2 — Coherence sweep (mandatory, BEFORE editing)

You are changing a **pattern**, not just a line. Before editing, find every existing instance of the
same concept so the change is coherent:

1. `grep`/search the whole codebase for the concept — the symbol, the call shape, the helper, the
   naming, the location. (e.g. re-homing one validator → grep **all** `validator:` / the old home.)
   When the sweep spans many files or naming variants, **dispatch the `cavecrew-investigator`
   subagent** ("list every instance of X — file:line") instead of grepping inline: its output is
   compressed, so the sibling list comes back without flooding the main thread. (CLAUDE.md §4
   Delegation table.)
2. Decide, explicitly:
   - **Align all** sibling instances in *this* change, OR
   - **Out of scope** → enumerate them and **schedule** a refactor (`docs/superpowers/specs/…`).
3. **Report the full sibling list** to the user. Never fix one instance and silently leave the rest
   divergent — that is how the codebase rots into incoherence.

> Real example (2026-06): re-homing `priceEuros` off `AppLocalizations` without sweeping found
> **27** `l10n.required` siblings across 3 forms. Fixing one would have left 27 divergent.

## Step 3 — Don't introduce an unsanctioned pattern

If the edit needs a new home/abstraction/location **not shown in the doc** (a new `core/` subfolder,
a new helper class, a new validator shape), that is a **probable convention violation** — STOP and
flag to the user before building it. Do not rationalize a novel structure into existence.

## Step 4 — Verify → use the `verify-flutter` skill

Gate 0 (convention compliance, ban-by-ban) + analyze (no paths) + tests + app-run for UI/schema.
For the ban-by-ban gate, prefer **dispatching the `convention-compliance-auditor` subagent** with
your diff + touched layers — it returns a compressed ban-by-ban verdict instead of you re-reading
every doc inline (CLAUDE.md §4 Delegation table). The coherence sweep from Step 2 and the compliance
gate are two halves of the same discipline: consistent with the rest of the code, and compliant with
the rules.
