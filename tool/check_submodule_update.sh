#!/usr/bin/env bash
#
# check_submodule_update.sh — SessionStart reminder that the pinned claude-flutter
# submodule is behind the latest upstream tag. Throttled to once/24h per project.
#
# Wired as a SessionStart hook in the consuming project's .claude/settings.json
# (init.sh does this). Prints ONE line to stdout when behind (which Claude Code
# injects as session context); silent when current or on any error/offline.
#
# NEVER fails the session: every failure path exits 0 with no output.
set -uo pipefail

# Script lives at <submodule>/tool/check_submodule_update.sh — submodule root is one up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || exit 0
SUBMODULE_DIR="$(cd "$SCRIPT_DIR/.." && pwd 2>/dev/null)" || exit 0

command -v git >/dev/null 2>&1 || exit 0

# --- throttle: once per 24h, keyed per project (each pins its own version) ----
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-flutter"
key="$(printf '%s' "$SUBMODULE_DIR" | cksum | cut -d' ' -f1)"
stamp="$cache_dir/${key}.stamp"
now="$(date +%s)"
if [[ -f "$stamp" ]]; then
  last="$(cat "$stamp" 2>/dev/null || echo 0)"
  # 86400s = 24h
  if [[ $(( now - last )) -lt 86400 ]]; then
    exit 0
  fi
fi
mkdir -p "$cache_dir" 2>/dev/null || exit 0
printf '%s' "$now" > "$stamp" 2>/dev/null || true

# --- pinned version ----------------------------------------------------------
pinned="$(git -C "$SUBMODULE_DIR" describe --tags --exact-match HEAD 2>/dev/null || true)"
[[ -n "$pinned" ]] || pinned="$(git -C "$SUBMODULE_DIR" rev-parse --short HEAD 2>/dev/null || true)"
[[ -n "$pinned" ]] || exit 0

# --- latest upstream tag (lightweight: no fetch, no working-tree change) ------
latest="$(git -C "$SUBMODULE_DIR" ls-remote --tags --refs origin 2>/dev/null \
  | sed 's#.*/tags/##' \
  | sort -V \
  | tail -1)"
[[ -n "$latest" ]] || exit 0

# --- compare (only warn when pinned is a tag AND strictly older) -------------
if [[ "$pinned" == "$latest" ]]; then
  exit 0
fi
# If pinned isn't a known tag (SHA fallback), still surface the latest tag.
older="$(printf '%s\n%s\n' "$pinned" "$latest" | sort -V | head -1)"
if [[ "$older" == "$latest" && "$pinned" != "$latest" ]]; then
  # pinned sorts newer than latest tag — nothing to suggest.
  exit 0
fi

echo "⬆ claude-flutter update available: ${pinned} (pinned) → ${latest} (latest). Bump: git -C .ai/claude-flutter fetch && git -C .ai/claude-flutter checkout ${latest}, then commit the pointer."
exit 0
