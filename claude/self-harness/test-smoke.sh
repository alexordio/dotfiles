#!/usr/bin/env bash
# Smoke test — run after touching lib.sh, schema.sql, or the allowlist:
#   ~/dotfiles/claude/self-harness/test-smoke.sh
# No fixtures, no framework: asserts against a throwaway temp DB.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

fail=0
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "  ✗ $desc — expected [$expected], got [$actual]"
    fail=1
  else
    echo "  ✓ $desc"
  fi
}

# Redirect SH_DB to a throwaway file for this test run only.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
SH_DB="$tmpdir/harness.sqlite"
db < "$DIR/schema.sql"

tables="$(db "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;" | tr '\n' ',')"
assert_eq "schema creates all 3 tables" "incidents,proposals,sessions," "$tables"

assert_eq "allowlist: skill -> dotfiles" "$DOTFILES_DIR" "$(allowlist_repo skill)"
assert_eq "allowlist: subagent -> dotfiles" "$DOTFILES_DIR" "$(allowlist_repo subagent)"
assert_eq "allowlist: claude_md -> dotfiles" "$DOTFILES_DIR" "$(allowlist_repo claude_md)"
assert_eq "allowlist: ordio_standards -> ordio-standards repo" "$ORDIO_STANDARDS_DIR" "$(allowlist_repo ordio_standards)"

if allowlist_repo not_a_real_surface >/dev/null 2>&1; then
  echo "  ✗ allowlist: unknown surface should fail"
  fail=1
else
  echo "  ✓ allowlist: unknown surface rejected"
fi

assert_eq "sql_escape doubles single quotes" "O''Brien" "$(sql_escape "O'Brien")"

# is_repo_local_target, against a real repo (ordio-standards) so the
# git-tracked check exercises actual git, not a fixture.
if is_repo_local_target "$ORDIO_STANDARDS_DIR" "CLAUDE.local.md"; then
  echo "  ✓ repo_local: untracked CLAUDE.local.md accepted"
else
  echo "  ✗ repo_local: untracked CLAUDE.local.md should be accepted"
  fail=1
fi

if is_repo_local_target "$ORDIO_STANDARDS_DIR" "README.md"; then
  echo "  ✗ repo_local: already-tracked README.md should be rejected"
  fail=1
else
  echo "  ✓ repo_local: already-tracked file rejected"
fi

if is_repo_local_target "$ORDIO_STANDARDS_DIR" "src/foo.txt"; then
  echo "  ✗ repo_local: disallowed path pattern should be rejected"
  fail=1
else
  echo "  ✓ repo_local: disallowed path pattern rejected"
fi

if is_repo_local_target "$DOTFILES_DIR" "CLAUDE.local.md"; then
  echo "  ✗ repo_local: repo outside Repos Ordio should be rejected"
  fail=1
else
  echo "  ✓ repo_local: repo outside Repos Ordio rejected"
fi

# A minimal insert/select round trip through the real INSERT shape used by
# digest-sessions.sh and mine-and-propose.sh.
db "INSERT INTO sessions (id, repo, project_path) VALUES ('s1', 'ordio', '/tmp/ordio');"
db "INSERT INTO incidents (session_id, repo, kind, surface, summary) VALUES ('s1', 'ordio', 'correction', 'symfony-debugger', 'test');"
count="$(db "SELECT COUNT(*) FROM incidents WHERE session_id='s1';")"
assert_eq "incident insert/select round trip" "1" "$count"

db "INSERT INTO proposals (target_surface, target_repo, target_path, content, summary, incident_ids) VALUES ('repo_local', '/tmp/x', 'CLAUDE.local.md', 'hello', 'test', '[]');"
count2="$(db "SELECT COUNT(*) FROM proposals WHERE target_surface='repo_local';")"
assert_eq "repo_local proposal insert/select round trip" "1" "$count2"

if [ "$fail" -eq 0 ]; then
  echo "All smoke checks passed."
else
  echo "Smoke checks FAILED."
  exit 1
fi
