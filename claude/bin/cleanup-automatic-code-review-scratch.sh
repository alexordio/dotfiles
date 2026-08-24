#!/usr/bin/env bash
# cleanup-automatic-code-review-scratch.sh — remove exactly one scratch dir
# the automatic-code-review skill created under /tmp/automatic-code-review/.
#
# Exists so the automatic-code-review skill's cleanup step can be allow-listed
# by this script's exact, fixed path instead of by an `rm -rf` prefix pattern.
# `rm -rf` prefix rules are ambiguous by nature (a rule meant to deny "rm -rf /"
# can end up matching "rm -rf /anything" once path-boundary edge cases are
# fixed — see self-harness discussion #65) and touching them is a security-
# sensitive change; this sidesteps that risk entirely by hardcoding the one
# directory it is allowed to ever delete.
#
# Usage: cleanup-automatic-code-review-scratch.sh <path>
#   <path> must be exactly /tmp/automatic-code-review/<something> — anything
#   else is refused.
set -euo pipefail

target="${1:-}"

if [[ -z "$target" ]]; then
  echo "usage: $0 <path under /tmp/automatic-code-review/>" >&2
  exit 2
fi

# Resolve to an absolute, symlink-free path before checking — a relative path
# or a symlink pointing outside the scratch dir must not slip through.
resolved="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)/$(basename "$target")" || {
  echo "refusing: cannot resolve '$target'" >&2
  exit 1
}

case "$resolved" in
  # macOS resolves /tmp to /private/tmp via symlink (pwd -P above follows
  # it) — accept both forms so the check works on macOS and Linux alike.
  /tmp/automatic-code-review/*|/private/tmp/automatic-code-review/*)
    ;;
  *)
    echo "refusing: '$resolved' is not under /tmp/automatic-code-review/" >&2
    exit 1
    ;;
esac

# Extra guard: never allow the target to collapse to the scratch root itself.
case "$resolved" in
  /tmp/automatic-code-review|/tmp/automatic-code-review/|/private/tmp/automatic-code-review|/private/tmp/automatic-code-review/)
    echo "refusing: won't delete the scratch root itself, only entries inside it" >&2
    exit 1
    ;;
esac

rm -rf -- "$resolved"
echo "removed: $resolved"
