#!/usr/bin/env bash
# block-truncated-verification.sh — PreToolUse hook on Bash.
#
# Blocks a verification command (test suite, build, CI-status check, deploy
# watcher) piped into `tail`/`head`. In a shell pipeline the exit code is the
# LAST command's, so a truncated `tail`/`head` with its own exit 0 makes a
# real failure upstream read as success -- and the truncated output can also
# hide the actual failure even when the exit code happens to be checked
# separately. Recurred 6 times: a stale Docker image left in place, a false
# "deploy finished" claim, an invalid "no failures" verification, a missed
# real PHPUnit failure, and a wrong endpoint count.
#
# This hook cannot rewrite the command (updatedInput was tested live and
# does not take effect in this Claude Code version) -- it can only block
# with instructions for the safe form.
#
# Known false-positive risk: matching is plain regex over the whole command
# string, not real shell parsing (unlike approve-compound-bash.sh's shfmt-AST
# approach). A command that merely CONTAINS the pattern as quoted text (e.g.
# testing/documenting this exact anti-pattern) will also be denied. Accepted
# tradeoff -- this is a personal deny-with-instructions hook, not something
# executing unattended, so the cost of a rare false positive is rewording the
# command, not lost work.
#
# Self-harness discussion #80.
set -uo pipefail

ALLOW_JSON='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<< "$input")
[[ -n "$command" ]] || { echo "$ALLOW_JSON"; exit 0; }

# Must be piped into tail or head to be a candidate at all.
[[ "$command" =~ \|[[:space:]]*(tail|head)([[:space:]]|$) ]] || { echo "$ALLOW_JSON"; exit 0; }

# And the part before the pipe must look like a verification command.
before_pipe="${command%%|*}"
if [[ "$before_pipe" =~ (make[[:space:]]+(test|lint)|phpunit|pnpm[[:space:]]+(run[[:space:]]+)?(build|test)|npm[[:space:]]+(run[[:space:]]+)?(build|test)|gh[[:space:]]+(pr[[:space:]]+checks|run[[:space:]]+(view|watch))|docker[[:space:]]+(build|compose[[:space:]]+build)|vendor/bin/phpunit) ]]; then
  jq -n --arg cmd "$command" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("Piping a verification command into tail/head hides real failures: the shell reports the LAST command'"'"'s exit code (tail/head'"'"'s, not the check'"'"'s), and the truncated output can hide the actual failure line even when you do check the exit code separately. Command: " + $cmd + "\n\nSafer form: redirect the full output to a file, check the real exit code, then read the file if you need to inspect it -- e.g. `cmd > /tmp/out.log 2>&1; code=$?; echo \"exit: $code\"` and `grep`/`tail` the file afterward, separately from the exit-code check.")}}'
  exit 0
fi

echo "$ALLOW_JSON"
