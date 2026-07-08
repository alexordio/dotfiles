#!/usr/bin/env bash
# Entry point, invoked daily by the com.alexander.claude-self-harness LaunchAgent.
# stdout/stderr are redirected to ~/.claude/self-harness/run.log by the plist.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

mkdir -p "$SH_HOME"
db < "$DIR/schema.sql"

echo "=== self-harness run: $(date) ==="
"$DIR/digest-sessions.sh"
"$DIR/mine-and-propose.sh"
"$DIR/notify-slack.sh"
