#!/usr/bin/env bash
# Daily root-cause mining: cluster accumulated incidents, draft at most 3
# narrow proposals/day. dotfiles/ordio-standards proposals are local git
# branches; repo_local proposals (personal, gitignored, per-repo) are plain
# file content since they're never committed. Never pushes, never opens a
# PR — that only happens in review.sh, when you accept.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

DAILY_BUDGET=3
TMP_DIR="$SH_HOME/tmp"
mkdir -p "$TMP_DIR"

today_count() {
  db "SELECT COUNT(*) FROM proposals WHERE date(created_at) = date('now');"
}

# Evidence shared by both passes: incidents from the last 60 days, and every
# past proposal + its verdict/feedback — this is the "retroactive" half of the
# loop: rejected patterns (and why) shape what gets proposed next, not just
# what gets accepted.
db -json "SELECT id, repo, kind, surface, summary, created_at FROM incidents WHERE created_at >= datetime('now', '-60 days');" \
  > "$TMP_DIR/incidents.json"
db -json "SELECT target_surface, target_path, summary, status, feedback FROM proposals;" \
  > "$TMP_DIR/proposal_history.json"

run_pass() {
  local surfaces="$1" repo_dir="$2" scope_note="$3"
  local remaining
  remaining=$(( DAILY_BUDGET - $(today_count) ))
  if [ "$remaining" -le 0 ]; then
    echo "  ✓ daily proposal budget already spent — skipping $repo_dir"
    return
  fi

  if [ -n "$(git -C "$repo_dir" status --porcelain)" ]; then
    echo "  ! $repo_dir has uncommitted changes — skipping this pass so a proposal branch doesn't sweep in unrelated work"
    return
  fi

  local base_branch default_br
  base_branch="$(git -C "$repo_dir" branch --show-current)"
  default_br="$(default_branch "$repo_dir")"
  if [ -n "$default_br" ] && [ "$base_branch" != "$default_br" ]; then
    echo "  ! $repo_dir is on '$base_branch', not its default branch '$default_br' — skipping so a proposal doesn't branch off unrelated work-in-progress"
    return
  fi

  local prompt
  prompt="You are the proposal stage of a self-improvement loop over Claude Code's own harness (skills, subagents, CLAUDE.md). Read $TMP_DIR/incidents.json (accumulated friction signals from real sessions) and $TMP_DIR/proposal_history.json (past proposals and their verdicts — an accepted or rejected entry is a strong prior; a rejection's feedback field tells you what was wrong about that angle, do not repeat it).

Group incidents by ROOT CAUSE, not surface symptom — two entries with kind=\"error\" can have unrelated causes. Only act on a cluster with 3 or more occurrences pointing at the same underlying cause.

Scope for this pass: $scope_note. You may ONLY touch: $surfaces. If you do not find a real cluster, or the real fix needs something outside that scope (e.g. a lint rule, a hook change), do NOT edit anything — instead emit a proposal with target_surface \"out_of_scope\" explaining what's needed and why editable-surface fixes won't work.

Before writing anything, Read at least one existing file of the same type you're about to touch, to copy its exact frontmatter and section structure — do not invent a new format.

Propose at most $remaining edits, each NARROW (one recurring, solvable pattern; state explicitly what must NOT change/break) — not a rewrite. For each edit you make:
1. Create a new branch off '$base_branch' named self-harness/<short-slug>.
2. Make the edit.
3. Commit it with a clear message.
Never push. Never open a PR. Never touch anything outside the stated scope.

When done, respond with ONLY this JSON (no prose, no markdown fences):
{\"proposals\": [{\"target_surface\": \"skill|subagent|claude_md|ordio_standards|out_of_scope\", \"target_path\": \"<repo-relative path, or null for out_of_scope>\", \"branch\": \"<branch name, or null for out_of_scope>\", \"summary\": \"<what changed and why, one paragraph>\", \"incident_ids\": [<the incident ids this is built on>]}]}"

  set +e
  result_json=$(cd "$repo_dir" && gtimeout 1500 claude -p "$prompt" --output-format json --permission-mode acceptEdits 2>/dev/null)
  exit_code=$?
  set -e
  if [ $exit_code -ne 0 ] || [ -z "$result_json" ]; then
    echo "  ! mining pass failed for $repo_dir (exit $exit_code) — will retry next run"
    # A kill mid-edit (e.g. gtimeout firing) can leave an uncommitted change
    # sitting in a repo you actively work in — that's a live, unreviewed
    # mutation, exactly what this whole system exists to prevent. Never leave
    # it behind.
    if [ -n "$(git -C "$repo_dir" status --porcelain)" ]; then
      echo "  ! killed mid-edit left uncommitted changes in $repo_dir — reverting"
      git -C "$repo_dir" checkout -- . 2>/dev/null || true
      git -C "$repo_dir" clean -fd 2>/dev/null || true
    fi
    git -C "$repo_dir" checkout "$base_branch" 2>/dev/null || true
    return
  fi

  proposals_json="$(parse_proposals "$result_json" "$(basename "$repo_dir")")"

  echo "$proposals_json" | jq -c '.[]?' | while read -r p; do
    target_surface=$(echo "$p" | jq -r '.target_surface')
    target_path=$(echo "$p" | jq -r '.target_path // empty')
    branch=$(echo "$p" | jq -r '.branch // empty')
    summary=$(echo "$p" | jq -r '.summary')
    incident_ids=$(echo "$p" | jq -c '.incident_ids // []')

    db "INSERT INTO proposals (target_surface, target_repo, target_path, branch, summary, incident_ids) VALUES (
      '$(sql_escape "$target_surface")',
      $( [ "$target_surface" != "out_of_scope" ] && echo "'$(sql_escape "$repo_dir")'" || echo "NULL" ),
      $( [ -n "$target_path" ] && echo "'$(sql_escape "$target_path")'" || echo "NULL" ),
      $( [ -n "$branch" ] && echo "'$(sql_escape "$branch")'" || echo "NULL" ),
      '$(sql_escape "$summary")',
      '$(sql_escape "$incident_ids")'
    );"
    echo "  → proposal: $target_surface ${target_path:-(out of scope)}"
  done

  # Leave the repo back on its base branch — a proposal branch left checked
  # out would fail the default-branch guard on every future run.
  git -C "$repo_dir" checkout "$base_branch" 2>/dev/null || true
}

run_pass "claude/agents/*.md, claude/personal-plugin/skills/*/SKILL.md, CLAUDE.md" \
  "$DOTFILES_DIR" \
  "your personal skills, subagents, and global CLAUDE.md"

run_pass "constitution/core.md, constitution/extensions/*.md" \
  "$ORDIO_STANDARDS_DIR" \
  "the shared engineering constitution synced into all Ordio repos — nothing outside constitution/"

# repo_local: personal, gitignored additions (CLAUDE.local.md or a new —
# never already-tracked — file under .claude/skills|agents) scoped to one
# specific repo. Runs read-only (--permission-mode plan, no Edit/Write) since
# these files are never committed anyway: review.sh writes them on accept,
# not this pass.
run_repo_local_pass() {
  local repo="$1" repo_dir="$ORDIO_REPOS_DIR/$repo"
  [ -d "$repo_dir/.git" ] || return

  local remaining
  remaining=$(( DAILY_BUDGET - $(today_count) ))
  [ "$remaining" -le 0 ] && return

  local existing_local_note=""
  if [ -f "$repo_dir/CLAUDE.local.md" ]; then
    existing_local_note="CLAUDE.local.md already exists in this repo — Read it first and extend it, don't propose a duplicate."
  fi

  local repo_incidents_file="$TMP_DIR/incidents_$repo.json"
  jq -c --arg repo "$repo" '[.[] | select(.repo == $repo)]' "$TMP_DIR/incidents.json" > "$repo_incidents_file"

  local prompt
  prompt="You are the personal-scope pass of a self-improvement loop, for the repo '$repo' only. Read $repo_incidents_file (friction signals from this repo only) and $TMP_DIR/proposal_history.json (past verdicts — do not repeat rejected angles).

Group by ROOT CAUSE. Only act on a cluster with 3 or more occurrences pointing at the same underlying cause. You may Read files in this repo for context, but you must NOT write or edit anything — this pass only proposes, it never touches disk. $existing_local_note

If there is a real cluster fixable by a PERSONAL, gitignored addition — CLAUDE.local.md, or a new file under .claude/skills/<name>/SKILL.md or .claude/agents/<name>.md, never a path already tracked by git — propose it with the FULL resulting file content (if CLAUDE.local.md already exists, include its current content plus your addition, not just the addition alone). Propose at most $remaining. If no real cluster, propose nothing.

Respond with ONLY this JSON (no prose, no markdown fences):
{\"proposals\": [{\"target_path\": \"CLAUDE.local.md|.claude/skills/<name>/SKILL.md|.claude/agents/<name>.md\", \"content\": \"<full file body>\", \"summary\": \"<what and why, one paragraph>\", \"incident_ids\": [<the incident ids this is built on>]}]}"

  set +e
  result_json=$(cd "$repo_dir" && gtimeout 600 claude -p "$prompt" --output-format json --permission-mode plan 2>/dev/null)
  exit_code=$?
  set -e
  if [ $exit_code -ne 0 ] || [ -z "$result_json" ]; then
    echo "  ! repo_local pass failed for $repo (exit $exit_code) — will retry next run"
    return
  fi

  proposals_json="$(parse_proposals "$result_json" "repo_local-$repo")"

  echo "$proposals_json" | jq -c '.[]?' | while read -r p; do
    target_path=$(echo "$p" | jq -r '.target_path')
    content=$(echo "$p" | jq -r '.content')
    summary=$(echo "$p" | jq -r '.summary')
    incident_ids=$(echo "$p" | jq -c '.incident_ids // []')

    if ! is_repo_local_target "$repo_dir" "$target_path"; then
      echo "  ! rejected by allowlist guard: $repo/$target_path"
      continue
    fi

    db "INSERT INTO proposals (target_surface, target_repo, target_path, content, summary, incident_ids) VALUES (
      'repo_local', '$(sql_escape "$repo_dir")', '$(sql_escape "$target_path")',
      '$(sql_escape "$content")', '$(sql_escape "$summary")', '$(sql_escape "$incident_ids")'
    );"
    echo "  → proposal: repo_local $repo/$target_path"
  done
}

jq -r '[.[].repo] | unique | .[]' "$TMP_DIR/incidents.json" | while IFS= read -r repo; do
  [ -n "$repo" ] && run_repo_local_pass "$repo"
done

rm -rf "$TMP_DIR"
