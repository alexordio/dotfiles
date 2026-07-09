#!/usr/bin/env bash
# Digest new Claude Code session content (Ordio repos only) into incidents.
# Cheap pass: one small `claude -p` call per session with new content, text in
# / JSON out, no tools involved — permission-mode plan blocks edits as a
# safety net.
#
# Sessions are rarely closed (just /clear'd), so a transcript file can keep
# growing for weeks. We track last_line per session and mine only the delta
# since last time — a long-lived session gets revisited every run instead of
# going dark after its first digest.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

PROJECTS_DIR="$HOME/.claude/projects"
# Project dirs are named after the cwd with slashes turned into dashes, e.g.
# "-Users-alexander-Desktop-Repos-Ordio-payroll-api". Matching this prefix is
# how we keep the whole pipeline scoped to Ordio repos only.
PROJECT_PREFIX="-Users-$(whoami)-Desktop-Repos-Ordio"

DIGEST_PROMPT_HEADER='You are given a raw excerpt of a Claude Code conversation (user/assistant text turns only — tool calls stripped). Find concrete, recurring-worthy signal in it:
- "correction": the user corrected, redirected, or pushed back on an approach.
- "error": a tool/command/test visibly failed and had to be fixed.
- "manual_workflow": the user manually walked through a multi-step process that looks like it could be a reusable skill.
- "denied_action": the user explicitly refused or blocked a proposed action.

Only report things with real signal — most excerpts have zero. Do not invent incidents to fill space.

Respond with ONLY this JSON (no prose, no markdown fences):
{"incidents": [{"kind": "correction|error|manual_workflow|denied_action", "surface": "<skill/subagent/tool name involved, or null>", "summary": "<one sentence, specific>"}]}

Transcript excerpt follows:
---
'

mkdir -p "$SH_HOME"
db < "$DIR/schema.sql"

shopt -s nullglob
for project_dir in "$PROJECTS_DIR/$PROJECT_PREFIX"*; do
  [ -d "$project_dir" ] || continue

  for transcript in "$project_dir"/*.jsonl; do
    session_id="$(basename "$transcript" .jsonl)"

    known_last_line="$(db "SELECT last_line FROM sessions WHERE id = '$(sql_escape "$session_id")';")"
    [ -z "$known_last_line" ] && known_last_line=0

    current_line_count="$(wc -l < "$transcript" | tr -d ' ')"
    [ "$current_line_count" -le "$known_last_line" ] && continue

    delta_range="$((known_last_line + 1)),${current_line_count}p"

    cwd="$(sed -n "$delta_range" "$transcript" | jq -rs '[.[] | select(.cwd) | .cwd] | first // ""' 2>/dev/null || true)"
    if [ -z "$cwd" ] || [[ "$cwd" != "$ORDIO_REPOS_DIR"* ]]; then
      continue
    fi
    repo="$(basename "$cwd")"

    text="$(sed -n "$delta_range" "$transcript" | jq -r 'select(.type == "user" or .type == "assistant") | {
        role: .message.role,
        text: (
          if (.message.content | type) == "string" then .message.content
          else ([.message.content[]? | select(.type == "text") | .text] | join("\n"))
          end
        )
      } | select(.text != "" and .text != null) | .role + ": " + .text' 2>/dev/null \
      | tail -c 200000 || true)"

    upsert_sql="INSERT INTO sessions (id, repo, project_path, last_line) VALUES (
        '$(sql_escape "$session_id")', '$(sql_escape "$repo")', '$(sql_escape "$cwd")', $current_line_count)
      ON CONFLICT(id) DO UPDATE SET last_line = $current_line_count, digested_at = datetime('now');"

    if [ -z "$text" ] || [ "${#text}" -lt 200 ]; then
      # Nothing substantive in this delta — advance the marker so we don't re-check it.
      db "$upsert_sql"
      continue
    fi

    prompt="${DIGEST_PROMPT_HEADER}${text}"

    set +e
    result_json="$(gtimeout 120 claude -p "$prompt" --output-format json --permission-mode plan 2>/dev/null)"
    exit_code=$?
    set -e
    if [ $exit_code -ne 0 ] || [ -z "$result_json" ]; then
      echo "  ! digest failed for session $session_id (exit $exit_code) — will retry next run"
      continue # don't advance last_line — retry this same delta next time
    fi

    incidents_json="$(echo "$result_json" | jq -r '.result // empty' | jq -c '.incidents // []' 2>/dev/null || echo '[]')"

    db "$upsert_sql"

    echo "$incidents_json" | jq -c '.[]?' | while read -r incident; do
      kind="$(echo "$incident" | jq -r '.kind')"
      surface="$(echo "$incident" | jq -r '.surface // empty')"
      summary="$(echo "$incident" | jq -r '.summary')"
      db "INSERT INTO incidents (session_id, repo, kind, surface, summary) VALUES (
        '$(sql_escape "$session_id")', '$(sql_escape "$repo")', '$(sql_escape "$kind")',
        $( [ -n "$surface" ] && echo "'$(sql_escape "$surface")'" || echo "NULL" ),
        '$(sql_escape "$summary")'
      );"
    done

    echo "  ✓ digested $repo/$session_id (lines $((known_last_line + 1))-$current_line_count)"
  done
done
