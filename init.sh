#!/usr/bin/env bash
#
# init.sh — wire a consuming Flutter project to this claude-flutter submodule.
#
# Creates the relative symlinks the project needs (conventions/architecture docs,
# bricks, check_conventions.sh, .claude agents+skills), auto-generates mason.yaml
# from the bricks/ directory, and drops a starter CLAUDE.md — all idempotent.
#
# Usage (from the consuming project root, after adding the submodule):
#   git submodule add git@github.com:Lord-Platypus/claude-flutter.git .ai/claude-flutter
#   .ai/claude-flutter/init.sh          # wire everything up
#   .ai/claude-flutter/init.sh --force  # also replace pre-existing real files/dirs
#
# Re-running is safe: correct symlinks are left untouched, existing mason.yaml /
# CLAUDE.md are never clobbered.
set -euo pipefail

SUBMODULE_REL=".ai/claude-flutter"

# --- flags -------------------------------------------------------------------
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# --- locate project root -----------------------------------------------------
# Script lives at <project>/.ai/claude-flutter/init.sh — project root is two up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

if [[ ! -d "$SUBMODULE_REL" ]]; then
  echo "error: $SUBMODULE_REL not found. Add the submodule first:" >&2
  echo "  git submodule add git@github.com:Lord-Platypus/claude-flutter.git $SUBMODULE_REL" >&2
  exit 1
fi

echo "==> project root: $PROJECT_ROOT"

# --- symlink map: link_path -> target (relative to the link's own directory) -
# Keep in sync with the project layout documented in CLAUDE.base.md.
declare -A LINKS=(
  ["bricks"]="$SUBMODULE_REL/bricks"
  ["docs/conventions"]="../$SUBMODULE_REL/docs/conventions"
  ["docs/architecture"]="../$SUBMODULE_REL/docs/architecture"
  ["docs/bricks.md"]="../$SUBMODULE_REL/docs/bricks.md"
  ["docs/bricks-reference-scaffolding.md"]="../$SUBMODULE_REL/docs/bricks-reference-scaffolding.md"
  ["docs/bricks-reference-usecases.md"]="../$SUBMODULE_REL/docs/bricks-reference-usecases.md"
  ["tool/check_conventions.sh"]="../$SUBMODULE_REL/tool/check_conventions.sh"
  [".claude/skills"]="../$SUBMODULE_REL/skills"
  [".claude/agents"]="../$SUBMODULE_REL/agents"
)

link_one() {
  local link_path="$1" target="$2"
  mkdir -p "$(dirname "$link_path")"

  if [[ -L "$link_path" ]]; then
    local current
    current="$(readlink "$link_path")"
    if [[ "$current" == "$target" ]]; then
      echo "    ok    $link_path"
      return
    fi
    rm -f "$link_path"                       # wrong-target symlink: replace
  elif [[ -e "$link_path" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      rm -rf "$link_path"                    # real file/dir + --force: overwrite
    else
      echo "    SKIP  $link_path (real path exists; re-run with --force to replace)" >&2
      return
    fi
  fi

  ln -s "$target" "$link_path"
  echo "    link  $link_path -> $target"
}

echo "==> symlinks"
for lp in "${!LINKS[@]}"; do link_one "$lp" "${LINKS[$lp]}"; done

# --- mason.yaml: auto-generate from the bricks/ directory (never drifts) ------
if [[ -e mason.yaml ]]; then
  echo "==> mason.yaml exists — leaving untouched"
else
  echo "==> generating mason.yaml from bricks/"
  {
    echo "bricks:"
    for brick in "$SUBMODULE_REL"/bricks/*/; do
      [[ -f "$brick/brick.yaml" ]] || continue
      name="$(basename "$brick")"
      printf '  %s:\n    path: bricks/%s\n' "$name" "$name"
    done
  } > mason.yaml
  echo "    wrote mason.yaml"
fi

# --- CLAUDE.md: starter that @imports the base router ------------------------
if [[ -e CLAUDE.md ]]; then
  echo "==> CLAUDE.md exists — leaving untouched"
else
  echo "==> writing starter CLAUDE.md"
  project_name="$(basename "$PROJECT_ROOT")"
  cat > CLAUDE.md <<EOF
# CLAUDE.md — $project_name

Generic Flutter clean-architecture router lives in the shared \`claude-flutter\`
submodule and is imported below. Read the matching \`docs/conventions/*\` file
(symlinked into the submodule) before touching code in that layer.

@$SUBMODULE_REL/CLAUDE.base.md

---

## Project-specific overrides

<!-- Add project-specific rules here (e.g. the l10n regen command, Floor version). -->
EOF
  echo "    wrote CLAUDE.md"
fi

echo "==> done. Fresh clones must run: git submodule update --init"
