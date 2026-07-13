# claude-flutter

Reusable Claude Code config for Flutter clean-architecture projects:
conventions docs, Mason bricks, the deterministic convention checker,
subagents, skills, and the CLAUDE.md router skeleton.

Consumed by projects as a git submodule (typically at `.ai/claude-flutter`),
wired in with symlinks that preserve original project-relative paths.

## Layout
- `docs/conventions/`, `docs/architecture/` — the rules
- `docs/bricks.md`, `docs/bricks-reference-*.md` — brick index
- `bricks/` — Mason bricks
- `tool/check_conventions.sh` — deterministic §1 ban checker
- `agents/`, `skills/` — Claude Code subagents + skills
- `CLAUDE.base.md` — generic router; project CLAUDE.md `@import`s this

## Consuming it
See a consumer project's `docs/superpowers/plans/*-claude-flutter-extraction.md`.
