#!/usr/bin/env bash
# Shared config for self-harness scripts. Sourced, not executed directly.

SH_HOME="$HOME/.claude/self-harness"
SH_DB="$SH_HOME/harness.sqlite"
ORDIO_REPOS_DIR="$HOME/Desktop/Repos Ordio"
DOTFILES_DIR="$HOME/dotfiles"
ORDIO_STANDARDS_DIR="$ORDIO_REPOS_DIR/ordio-standards"

# launchd runs jobs with a minimal PATH (/usr/bin:/bin:/usr/sbin:/sbin) — claude
# (nvm-managed) and gh/jq (Homebrew) don't live there. Extend it so every entry
# point works whether launchd or you invoke it.
# ponytail: globs the highest installed nvm node version instead of hardcoding
# one — if `nvm install` changes it later, this re-resolves on its own.
nvm_bin="$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1)"
export PATH="${nvm_bin:+$nvm_bin:}/opt/homebrew/bin:/usr/local/bin:$PATH"

# Allowlist: the only two repos a proposal may ever touch, keyed by target_surface.
# ponytail: hardcoded 2-row map, not a config file — add a line if a third surface
# is ever needed, don't build a schema for it speculatively.
allowlist_repo() {
  case "$1" in
    skill | subagent | claude_md) echo "$DOTFILES_DIR" ;;
    ordio_standards) echo "$ORDIO_STANDARDS_DIR" ;;
    *) return 1 ;;
  esac
}

db() {
  sqlite3 "$SH_DB" "$@"
}

# repo_local targets aren't a fixed repo (any Ordio repo qualifies), so they get
# their own guard instead of a allowlist_repo() entry: must be a personal,
# never-shared path, and must not already be tracked by git (if it already
# exists as a team-committed file, it's not "personal" — refuse it).
is_repo_local_target() {
  local repo_dir="$1" rel_path="$2"
  case "$repo_dir" in
    "$ORDIO_REPOS_DIR"/*) ;;
    *) return 1 ;;
  esac
  case "$rel_path" in
    CLAUDE.local.md | .claude/skills/* | .claude/agents/*) ;;
    *) return 1 ;;
  esac
  if git -C "$repo_dir" ls-files --error-unmatch "$rel_path" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}
