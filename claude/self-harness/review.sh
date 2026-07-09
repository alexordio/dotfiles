#!/usr/bin/env bash
# Interactive review of pending proposals. You are the verifier — nothing here
# runs an LLM or auto-applies anything. Run it whenever you like:
#   ~/dotfiles/claude/self-harness/review.sh

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

ids="$(db "SELECT id FROM proposals WHERE status = 'pending' ORDER BY created_at;")"

if [ -z "$ids" ]; then
  echo "No pending proposals."
  exit 0
fi

while IFS= read -r id <&3; do
  row_json="$(db -json "SELECT * FROM proposals WHERE id = $id;" | jq -c '.[0]')"
  target_surface="$(echo "$row_json" | jq -r '.target_surface')"
  target_repo="$(echo "$row_json" | jq -r '.target_repo // empty')"
  target_path="$(echo "$row_json" | jq -r '.target_path // empty')"
  branch="$(echo "$row_json" | jq -r '.branch // empty')"
  content="$(echo "$row_json" | jq -r '.content // empty')"
  summary="$(echo "$row_json" | jq -r '.summary')"

  echo ""
  echo "──────────────────────────────────────────────"
  echo "#$id  [$target_surface]  ${target_path:-(no editable-surface fix — see summary)}"
  echo "$summary"
  echo ""

  if [ "$target_surface" = "repo_local" ]; then
    old_file="$target_repo/$target_path"
    [ -f "$old_file" ] || old_file=/dev/null
    diff -u "$old_file" - <<< "$content" || true
    echo ""
    read -r -p "[a]ccept / [r]eject / [s]kip > " choice
  elif [ -n "$branch" ] && [ -n "$target_repo" ]; then
    base="$(git -C "$target_repo" merge-base HEAD "$branch" 2>/dev/null || echo "")"
    if [ -n "$base" ]; then
      git -C "$target_repo" --no-pager diff "$base..$branch"
    else
      echo "  ! could not diff branch '$branch' in $target_repo — was it already merged/deleted?"
    fi
    echo ""
    read -r -p "[a]ccept / [r]eject / [s]kip > " choice
  else
    read -r -p "[a]cknowledge / [s]kip > " choice
  fi

  case "$choice" in
    a)
      if [ "$target_surface" = "repo_local" ]; then
        if is_repo_local_target "$target_repo" "$target_path"; then
          mkdir -p "$(dirname "$target_repo/$target_path")"
          printf '%s' "$content" > "$target_repo/$target_path"
          echo "  ✓ wrote $target_repo/$target_path (gitignored, never committed)"
        else
          echo "  ! guard re-check failed (path now tracked by git, or no longer valid) — not writing. Apply manually if you're sure."
        fi
      elif [ -n "$branch" ] && [ -n "$target_repo" ]; then
        if [ "$target_surface" = "ordio_standards" ]; then
          git -C "$target_repo" push -u origin "$branch"
          pr_url="$(cd "$target_repo" && gh pr create --head "$branch" --title "self-harness: ${summary%%.*}" --body "$summary" 2>&1 || true)"
          echo "  → $pr_url"
        else
          if [ -n "$(git -C "$target_repo" status --porcelain)" ]; then
            echo "  ! $target_repo has uncommitted changes — merge '$branch' yourself when it's clean:"
            echo "      git -C \"$target_repo\" merge $branch"
          else
            git -C "$target_repo" merge --no-edit "$branch"
            echo "  ✓ merged into $(git -C "$target_repo" branch --show-current)"
          fi
        fi
      fi
      db "UPDATE proposals SET status='accepted', decided_at=datetime('now') WHERE id=$id;"
      ;;
    r)
      read -r -p "Why? (feeds the next mining pass) " feedback
      db "UPDATE proposals SET status='rejected', feedback='$(sql_escape "$feedback")', decided_at=datetime('now') WHERE id=$id;"
      if [ -n "$branch" ] && [ -n "$target_repo" ]; then
        git -C "$target_repo" branch -D "$branch" 2>/dev/null || true
      fi
      ;;
    *)
      echo "  (left pending)"
      ;;
  esac
done 3<<< "$ids"
