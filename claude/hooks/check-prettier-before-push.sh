#!/usr/bin/env bash
# check-prettier-before-push.sh — PreToolUse hook on Bash.
#
# Blocks `git push` in a pnpm repo that has no lefthook/husky pre-commit tool
# of its own, if `prettier --check` would fail. CI runs format:check
# separately from lint (ESLint), so a local ESLint-only pass reads as green
# while Prettier still fails in CI -- happened 5 times, the CLAUDE.md prose
# rule about this hasn't held.
#
# Only acts on repos with no existing pre-commit formatter (payroll-frontend,
# x) -- web already runs `pnpm prettier --write` via lefthook pre-commit, so
# this would just be redundant noise there.
#
# Self-harness discussion #79.
set -uo pipefail

ALLOW_JSON='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<< "$input")
[[ -n "$command" ]] || { echo "$ALLOW_JSON"; exit 0; }
[[ "$command" == *"git push"* ]] || { echo "$ALLOW_JSON"; exit 0; }

toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
[[ -n "$toplevel" ]] || { echo "$ALLOW_JSON"; exit 0; }

# Not a pnpm repo -> nothing to check.
[[ -f "$toplevel/pnpm-lock.yaml" ]] || { echo "$ALLOW_JSON"; exit 0; }

# Already has its own pre-commit formatter -> don't duplicate (e.g. web/lefthook).
if [[ -f "$toplevel/lefthook.yml" || -d "$toplevel/.husky" ]]; then
  echo "$ALLOW_JSON"
  exit 0
fi

if (cd "$toplevel" && pnpm exec prettier --check . > /tmp/prettier-check-output.txt 2>&1); then
  echo "$ALLOW_JSON"
  exit 0
fi

jq -n --arg msg "prettier --check failed in $toplevel -- CI's Linting job runs this separately from ESLint, so pushing now would go red there even if lint passed locally. Run 'pnpm format' (or the repo's format script) and commit, then push again. First few offending lines:
$(head -15 /tmp/prettier-check-output.txt)" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$msg}}'
