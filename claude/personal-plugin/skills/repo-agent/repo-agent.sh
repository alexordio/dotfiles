#!/usr/bin/env bash
#
# repo-agent.sh — spawn a Claude Code agent ROOTED in another repo.
#
# Why: editing a sibling repo through the current session (via
# permissions.additionalDirectories) grants file access but does NOT load that
# repo's CLAUDE.md / .claude config. A process whose cwd IS the repo loads its
# full conventions (CLAUDE.md, settings, rules, skills, hooks, subagents)
# natively. Use this for real work (edit + git + build + PR) in another repo,
# and for cross-repo fan-out (one rooted agent per repo, in parallel).
#
# By default the agent works in an isolated git worktree, not your actual
# checkout — two things editing the same checkout can silently destroy each
# other's uncommitted work (e.g. a branch switch wiping the agent's edits, or
# vice versa). When the agent finishes:
#   - no changes made          -> worktree + branch are deleted, nothing to do
#   - changes made, checkout clean -> worktree is folded into your checkout:
#     removed, then `git checkout <branch>` there so it shows up in your IDE
#   - changes made, checkout dirty -> nothing is touched; the worktree path
#     and branch are printed so you can decide what to do
#
# Usage:
#   repo-agent.sh <repo> [--yolo] [--no-worktree] [--model <m>] [--json] [--add-dir <p>]... <task...>
#
#   <repo>  Absolute path, OR a bare name resolved under $ORDIO_REPOS_ROOT
#           (default: "$HOME/Desktop/Repos Ordio"). e.g. `ordio`, `sdk.js`.
#   <task>  The instruction for the agent (everything after the options).
#
# Options:
#   --yolo            Full autonomy: --dangerously-skip-permissions (edits, git
#                     push, pnpm, gh — no prompts). Use only for trusted tasks.
#                     Without it, runs in acceptEdits: file edits flow, but
#                     commands that would prompt (git push, pnpm, gh pr create)
#                     are denied in headless mode — i.e. investigate+edit only.
#   --no-worktree     Work directly in the shared checkout instead (old
#                     behavior) — only when you deliberately want that.
#   --timeout <min>   Kill the run if it's still going after <min> minutes
#                     (default 20). A headless run can hang forever on a
#                     permission prompt nobody can answer (e.g. a pnpm
#                     install confirmation) — without this it blocks
#                     indefinitely with zero feedback. Requires GNU `timeout`
#                     (or `gtimeout` from coreutils); if neither is on PATH,
#                     runs without a timeout and prints a warning.
#   --model <m>       Model alias/id passed to --model.
#   --json            Machine output (--output-format json) for orchestration.
#   --add-dir <p>     Extra directory the rooted agent may also touch (repeatable).
#
# Examples:
#   repo-agent.sh ordio "Add a nullable column X to DTO Y and a test"
#   repo-agent.sh sdk.js --yolo "Regenerate src/core, commit, push, open RC PR"
#   repo-agent.sh /abs/path/to/web --json "List the routes under app/"
#
set -euo pipefail

REPOS_ROOT="${ORDIO_REPOS_ROOT:-$HOME/Desktop/Repos Ordio}"

if [[ $# -lt 2 ]]; then
  awk 'NR==1 && /^#!/ {next} /^#/ {sub(/^# ?/,""); print; next} {exit}' "$0" >&2
  exit 2
fi

command -v claude >/dev/null 2>&1 || { echo "error: 'claude' CLI not on PATH" >&2; exit 127; }

repo_arg="$1"; shift

perm=(--permission-mode acceptEdits)
out=()
extra=()
model=()
use_worktree=1
timeout_min=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yolo) perm=(--dangerously-skip-permissions); shift ;;
    --no-worktree) use_worktree=0; shift ;;
    --timeout) timeout_min="$2"; shift 2 ;;
    --json) out=(--output-format json); shift ;;
    --model) model=(--model "$2"); shift 2 ;;
    --add-dir) extra+=(--add-dir "$2"); shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

timeout_cmd=()
if command -v timeout >/dev/null 2>&1; then
  timeout_cmd=(timeout "${timeout_min}m")
elif command -v gtimeout >/dev/null 2>&1; then
  timeout_cmd=(gtimeout "${timeout_min}m")
else
  echo ">> warning: no 'timeout'/'gtimeout' on PATH — running with no time limit (brew install coreutils to enable)" >&2
fi

task="$*"
[[ -n "$task" ]] || { echo "error: no task given" >&2; exit 2; }

# Resolve repo: absolute/existing path as-is, otherwise under REPOS_ROOT.
if [[ -d "$repo_arg" ]]; then
  repo_dir="$repo_arg"
elif [[ -d "$REPOS_ROOT/$repo_arg" ]]; then
  repo_dir="$REPOS_ROOT/$repo_arg"
else
  echo "error: repo not found: '$repo_arg' (looked in CWD and '$REPOS_ROOT')" >&2
  exit 1
fi

repo_dir="$(cd "$repo_dir" && pwd)"
work_dir="$repo_dir"
wt_dir=""
wt_branch=""
base_branch=""

if [[ "$use_worktree" -eq 1 ]] && git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
  base_branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)"
  wt_branch="repo-agent/$(basename "$repo_dir")-$$"
  wt_dir="$(mktemp -d "${TMPDIR:-/tmp}/repo-agent-XXXXXX")"
  rmdir "$wt_dir"
  git -C "$repo_dir" worktree add -q -b "$wt_branch" "$wt_dir" "$base_branch"
  work_dir="$wt_dir"
  echo ">> isolated worktree: $wt_dir (branch: $wt_branch, off: $base_branch)" >&2
fi

echo ">> repo-agent rooted in: $work_dir" >&2
echo ">> mode: ${perm[*]}" >&2

cd "$work_dir"
set +e
"${timeout_cmd[@]}" claude -p "$task" "${perm[@]}" "${model[@]}" "${out[@]}" "${extra[@]}"
code=$?
set -e

if [[ $code -eq 124 ]]; then
  echo ">> TIMED OUT after ${timeout_min}m — likely stuck on an unanswerable permission prompt (e.g. pnpm install)." >&2
  if [[ -n "$wt_dir" ]]; then
    echo ">> the checkout at $repo_dir was never touched; the agent's partial work (if any) is on branch $wt_branch at $wt_dir for you to inspect or discard." >&2
  fi
  exit $code
fi

if [[ -n "$wt_dir" ]]; then
  dirty="$(git -C "$wt_dir" status --porcelain)"
  ahead="$(git -C "$wt_dir" rev-list --count "$base_branch..HEAD")"
  if [[ -z "$dirty" && "$ahead" -eq 0 ]]; then
    git -C "$repo_dir" worktree remove "$wt_dir"
    git -C "$repo_dir" branch -D "$wt_branch" >/dev/null
    echo ">> no changes, worktree removed" >&2
  elif [[ -z "$(git -C "$repo_dir" status --porcelain)" ]]; then
    git -C "$repo_dir" worktree remove "$wt_dir" --force
    git -C "$repo_dir" checkout -q "$wt_branch"
    echo ">> checkout is clean, switched $repo_dir to branch $wt_branch" >&2
  else
    echo ">> your checkout at $repo_dir has uncommitted changes — leaving the agent's work on branch $wt_branch at $wt_dir for you to review" >&2
  fi
fi

exit $code
