#!/usr/bin/env bash
#
# bootstrap.sh — one-shot MACHINE-GLOBAL Claude Code setup.
#
# NOT Flutter-specific. Installs the generic tools this author expects on every
# machine, into ~/.claude (user scope):
#   - graphify                    (PyPI `graphifyy`; ships its own Claude skill)
#   - superpowers                 (marketplace: anthropics/claude-plugins-official)
#   - caveman                     (marketplace: JuliusBrussee/caveman)
#   - andrej-karpathy-skills      (marketplace: forrestchang/andrej-karpathy-skills)
#
# Idempotent: already-installed tools are skipped. Safe to re-run.
# Run once on a fresh machine, then RESTART Claude Code to load new plugins.
#
#   .ai/claude-flutter/global/bootstrap.sh
#
set -euo pipefail

echo "==> claude-flutter machine bootstrap (global, not Flutter-specific)"

# --- preflight ---------------------------------------------------------------
missing=0
for bin in pipx claude; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "  ERROR: '$bin' not found on PATH." >&2
    case "$bin" in
      pipx)   echo "         install: python3 -m pip install --user pipx && pipx ensurepath" >&2 ;;
      claude) echo "         install Claude Code first: https://claude.com/claude-code" >&2 ;;
    esac
    missing=1
  fi
done
[[ "$missing" -eq 0 ]] || { echo "==> aborting: install the above, re-run." >&2; exit 1; }

# --- graphify (PyPI package that ships its own skill) ------------------------
echo "==> graphify"
if command -v graphify >/dev/null 2>&1; then
  echo "    ok    graphify already installed ($(graphify --help >/dev/null 2>&1 && echo present))"
else
  echo "    install  pipx install graphifyy"
  pipx install graphifyy
fi
# Copy the skill into ~/.claude/skills/graphify (idempotent; refreshes on re-run).
echo "    skill    graphify install --platform claude"
graphify install --platform claude

# --- marketplace plugins -----------------------------------------------------
# pairs: "<marketplace-name> <github-repo> <plugin@marketplace>"
plugins=(
  "claude-plugins-official anthropics/claude-plugins-official superpowers@claude-plugins-official"
  "caveman JuliusBrussee/caveman caveman@caveman"
  "karpathy-skills forrestchang/andrej-karpathy-skills andrej-karpathy-skills@karpathy-skills"
)

echo "==> marketplace plugins"
market_list="$(claude plugin marketplace list 2>/dev/null || true)"
installed_list="$(claude plugin list 2>/dev/null || true)"

for row in "${plugins[@]}"; do
  read -r market repo plugin <<<"$row"
  name="${plugin%@*}"

  if grep -q "$market" <<<"$market_list"; then
    echo "    ok    marketplace $market"
  else
    echo "    add   marketplace $market ($repo)"
    claude plugin marketplace add "$repo"
  fi

  if grep -q "$name" <<<"$installed_list"; then
    echo "    ok    plugin $name"
  else
    echo "    install  $plugin"
    claude plugin install "$plugin" -s user
  fi
done

echo "==> done. RESTART Claude Code to load newly-installed plugins."
