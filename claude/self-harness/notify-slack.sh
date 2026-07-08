#!/usr/bin/env bash
# Post today's new pending proposals to Slack via an Incoming Webhook.
# Webhook URL lives outside dotfiles (never committed): ~/.claude/self-harness/slack-webhook.txt

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

WEBHOOK_FILE="$SH_HOME/slack-webhook.txt"

if [ ! -f "$WEBHOOK_FILE" ]; then
  echo "  ! no $WEBHOOK_FILE — skipping Slack notification (create it with your Incoming Webhook URL)"
  exit 0
fi

count="$(db "SELECT COUNT(*) FROM proposals WHERE status = 'pending' AND date(created_at) = date('now');")"
if [ "$count" -eq 0 ]; then
  exit 0
fi

lines="$(db "SELECT '- [' || target_surface || '] ' || summary FROM proposals WHERE status = 'pending' AND date(created_at) = date('now');")"
text="self-harness: $count new proposal(s) today.
$lines

Review with: ~/dotfiles/claude/self-harness/review.sh"

webhook_url="$(cat "$WEBHOOK_FILE")"
payload="$(jq -n --arg text "$text" '{text: $text}')"
curl -sS -X POST -H 'Content-Type: application/json' -d "$payload" "$webhook_url" >/dev/null
