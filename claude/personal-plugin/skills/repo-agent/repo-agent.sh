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
# Usage:
#   repo-agent.sh <repo> [--yolo] [--model <m>] [--json] [--add-dir <p>]... <task...>
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yolo) perm=(--dangerously-skip-permissions); shift ;;
    --json) out=(--output-format json); shift ;;
    --model) model=(--model "$2"); shift 2 ;;
    --add-dir) extra+=(--add-dir "$2"); shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

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
echo ">> repo-agent rooted in: $repo_dir" >&2
echo ">> mode: ${perm[*]}" >&2

cd "$repo_dir"
exec claude -p "$task" "${perm[@]}" "${model[@]}" "${out[@]}" "${extra[@]}"
