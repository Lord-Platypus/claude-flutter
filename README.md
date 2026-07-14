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
- `tool/check_submodule_update.sh` — SessionStart update reminder (see below)
- `agents/`, `skills/` — Claude Code subagents + skills
- `CLAUDE.base.md` — generic router; project CLAUDE.md `@import`s this
- `init.sh` — one-shot wiring script for a consuming project
- `global/bootstrap.sh` — machine-global tool install (NOT Flutter-specific)

## Consuming it
From a new Flutter project root:

```bash
git submodule add git@github.com:Lord-Platypus/claude-flutter.git .ai/claude-flutter
.ai/claude-flutter/init.sh
```

`init.sh` creates the project-relative symlinks (conventions/architecture docs,
`bricks/`, `check_conventions.sh`, `.claude/{agents,skills}`), generates
`mason.yaml` from `bricks/`, and drops a starter `CLAUDE.md` that `@import`s
`CLAUDE.base.md`. It is idempotent; pass `--force` to replace pre-existing real
files/dirs. Fresh clones of a wired project just need
`git submodule update --init`.

### Updating the pinned version
Submodules pin one commit — upstream changes do **not** auto-propagate. Bump per
project when you want them:

```bash
git -C .ai/claude-flutter fetch
git -C .ai/claude-flutter checkout <tag>
git add .ai/claude-flutter && git commit -m "chore: bump claude-flutter to <tag>"
```

`init.sh` also wires a **SessionStart hook** (`tool/check_submodule_update.sh`)
into the project's `.claude/settings.json`. Once per day it compares the pinned
tag against the latest upstream tag (`git ls-remote`, no fetch) and, when behind,
prints a one-line reminder to bump. Silent when current or offline; never fails
the session.

## Machine bootstrap (global, not Flutter)
`global/bootstrap.sh` installs the author's generic Claude tooling into
`~/.claude` on a fresh machine — idempotent, safe to re-run:

```bash
.ai/claude-flutter/global/bootstrap.sh   # then restart Claude Code
```

Installs graphify (`pipx install graphifyy` + its skill) and the superpowers,
caveman, and andrej-karpathy-skills plugins. This is machine-global setup that
happens to ride along in this repo — it is **not** part of the Flutter
clean-architecture config.
