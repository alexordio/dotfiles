#!/usr/bin/env bash
# warn-concurrent-session.sh — SessionStart hook.
#
# Warns (does not block) when another live `claude` process already has its
# cwd inside the same git repo this session is starting in. Two Claude Code
# sessions sharing one checkout can silently destroy each other's work: one
# switches branches or commits while the other has uncommitted edits, or a
# subagent mutates a file (e.g. regenerating a JWT keypair) mid-run of the
# other session. This can only warn — it has no way to stop the other
# session or force either one into a worktree.
#
# Self-harness discussion #74.
set -uo pipefail

MY_PID="$PPID"
MY_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$MY_TOPLEVEL" ] || exit 0   # not in a git repo — nothing to warn about

OTHERS=""
for pid in $(pgrep -x claude 2>/dev/null); do
  [ "$pid" != "$MY_PID" ] || continue
  cwd="$(lsof -a -d cwd -p "$pid" -Fn 2>/dev/null | tail -1 | sed 's/^n//')"
  [ -n "$cwd" ] || continue
  toplevel="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
  [ "$toplevel" = "$MY_TOPLEVEL" ] || continue
  OTHERS="$OTHERS $pid"
done

if [ -n "$OTHERS" ]; then
  jq -n --arg msg "Warning: another live Claude Code session (PID:$OTHERS) already has its working directory inside this same repo ($MY_TOPLEVEL). Two sessions sharing one checkout can clobber each other's branch switches, commits, or uncommitted edits — consider working in a separate worktree instead." \
    '{systemMessage: $msg}'
fi
exit 0
