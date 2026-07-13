#!/usr/bin/env bash
# tool/check_conventions.sh — deterministic subset of CLAUDE.md §1 bans.
# Pure grep, no network, no writes. Exit 0 = clean, exit 1 = violations printed.
#
# Default scope: .dart files changed vs HEAD (staged + unstaged + untracked).
# --all: every .dart file under lib/.  Generated *.g.dart always skipped.
# Run automatically by the Stop verify-gate hook on changed files.
#
# Checked bans (greppable subset — judgment bans stay in CLAUDE.md §1):
#   C1 clean-architecture dependency direction: presentation → domain ← data
#      - domain/ imports no flutter/floor/bloc package and no data/ or presentation/
#      - presentation/ imports no data/ layer and no floor
#      - data/ imports no presentation/ layer
#   C2 raw widget in a feature where a core/app_design_system App* twin exists.
#      Ban list is DERIVED live from `class App<Name>` in app_design_system/widgets/
#      (+ static seed from presentation-design-system.md §5), so it follows the
#      design system as it grows — no script edit needed for new App* widgets.
#   C3 inline Color(0x...) in a feature                  (presentation-design-system.md §6)
#   C4 AppLocalizations inside a BLoC                    (bloc-rules.md §1)
#   C5 cross-feature presentation import                 (architecture.md §1, layers.md §4)
#   C6 .then( instead of async/await                     (code-quality.md §13)
#   C7 .replaceFirst(':id' route-path hack               (presentation-navigation.md §4)
#   C8 brick-reference drift: every brick in mason.yaml must be referenced in
#      docs/bricks.md, .claude/skills/mason-brick/SKILL.md and
#      .claude/agents/mason-scaffolder.md                (mason.md, CLAUDE.md §4)

set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

mode="${1:-changed}"

if [ "$mode" = "--all" ]; then
  files=$(find lib -name '*.dart' ! -name '*.g.dart')
  config_changed=1
else
  files=$( (git diff --name-only HEAD -- 'lib/**/*.dart' 'lib/*.dart'; \
            git ls-files --others --exclude-standard -- 'lib/**/*.dart' 'lib/*.dart') \
          | sort -u | grep -v '\.g\.dart$' || true)
  config_changed=$(git diff --name-only HEAD -- mason.yaml 'bricks/*' 'docs/bricks*.md' | head -1)
fi

fail=0
report() { # $1=location  $2=ban text
  printf '%s: %s\n' "$1" "$2"
  fail=1
}

# --- C8: brick-reference drift (only when mason surface changed, or --all) ---
if [ -n "$config_changed" ] && [ -f mason.yaml ]; then
  brick_refs="docs/bricks.md .claude/skills/mason-brick/SKILL.md .claude/agents/mason-scaffolder.md"
  for b in $(grep -oE '^  [a-z_]+:' mason.yaml | tr -d ' :'); do
    for ref in $brick_refs; do
      [ -f "$ref" ] || continue
      grep -qE "\b${b}\b" "$ref" \
        || report "mason.yaml" "C8 brick '${b}' not referenced in ${ref} — update the reference"
    done
  done
fi

[ -z "$files" ] && exit $fail

# C2 ban list: seed (doc examples) + names derived from App* widgets in the design system
seed='ElevatedButton|FilledButton|OutlinedButton|TextButton|Card'
derived=$(grep -rhoE 'class App[A-Z][A-Za-z]*' lib/core/app_design_system/widgets/ 2>/dev/null \
          | sed 's/^class App//' | sort -u | paste -sd'|' -)
banned_widgets="$seed${derived:+|$derived}"

for f in $files; do
  [ -f "$f" ] || continue

  case "$f" in
    lib/features/*/domain/*)
      while IFS= read -r hit; do
        report "$f:$hit" "C1 domain/ must stay pure — no flutter/floor/bloc import"
      done < <(grep -nE "import 'package:(flutter|floor|flutter_bloc|bloc)[/']" "$f")
      while IFS= read -r hit; do
        report "$f:$hit" "C1 domain/ must not import data/ or presentation/ layers"
      done < <(grep -nE "import 'package:[^']*/features/[^/']+/(data|presentation)/" "$f")
      ;;
    lib/features/*/data/*)
      while IFS= read -r hit; do
        report "$f:$hit" "C1 data/ must not import a presentation/ layer"
      done < <(grep -nE "import 'package:[^']*/features/[^/']+/presentation/" "$f")
      ;;
    lib/features/*/presentation/*)
      while IFS= read -r hit; do
        report "$f:$hit" "C1 presentation/ must not import a data/ layer (go via domain)"
      done < <(grep -nE "import 'package:([^']*/features/[^/']+/data/|floor[/'])" "$f")

      while IFS= read -r hit; do
        report "$f:$hit" "C2 raw widget in feature — use its App* design-system twin"
      done < <(grep -nE "\b($banned_widgets)\(" "$f")

      while IFS= read -r hit; do
        report "$f:$hit" "C3 inline colour in feature — use context.theme.*"
      done < <(grep -nE 'Color\(0x' "$f")

      this_feature=$(printf '%s' "$f" | sed -E 's|^lib/features/([^/]+)/.*|\1|')
      while IFS= read -r hit; do
        report "$f:$hit" "C5 cross-feature presentation import — features talk via domain only"
      done < <(grep -nE "import 'package:[^']*/features/[^/']+/presentation/" "$f" \
               | grep -v "/features/${this_feature}/presentation/")
      ;;
  esac

  case "$f" in
    lib/features/*/presentation/*/bloc/*|lib/features/*/presentation/bloc/*)
      while IFS= read -r hit; do
        report "$f:$hit" "C4 AppLocalizations inside BLoC — emit typed Exception, widget translates"
      done < <(grep -n 'AppLocalizations' "$f")
      ;;
  esac

  while IFS= read -r hit; do
    report "$f:$hit" "C6 .then( — use async/await"
  done < <(grep -nE '\.then\(' "$f")

  while IFS= read -r hit; do
    report "$f:$hit" "C7 route-path .replaceFirst(':' hack — use pushNamed + pathParameters"
  done < <(grep -nE "\.replaceFirst\(':" "$f")
done

exit $fail
