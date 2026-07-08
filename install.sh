#!/usr/bin/env bash
# install.sh — bootstrap dotfiles on a new machine
# Idempotent: safe to re-run anytime.

set -euo pipefail

DOTFILES_DIR="${HOME}/dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Error: expected ~/dotfiles to exist. Clone the repo first."
  exit 1
fi

echo "Installing dotfiles from $DOTFILES_DIR"

# Helper: create symlink, backing up any existing real file
link() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$(readlink "$dst" 2>/dev/null)" = "$src" ]; then
      echo "  ✓ $dst (already linked)"
      return
    fi
    local backup="${dst}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "  ! $dst exists — backing up to $backup"
    mv "$dst" "$backup"
  fi

  ln -s "$src" "$dst"
  echo "  → $dst"
}

# Helper: check command exists
has() {
  command -v "$1" >/dev/null 2>&1
}

echo ""
echo "Linking Claude config..."
link "$DOTFILES_DIR/claude/CLAUDE.md"                    "$HOME/.claude/CLAUDE.md"
link "$DOTFILES_DIR/claude/settings.json"                "$HOME/.claude/settings.json"
link "$DOTFILES_DIR/claude/statusline.sh"                "$HOME/.claude/statusline.sh"
link "$DOTFILES_DIR/claude/hooks/detect-docker.sh"       "$HOME/.claude/hooks/detect-docker.sh"

for agent in "$DOTFILES_DIR"/claude/agents/*.md; do
  [ -f "$agent" ] || continue
  link "$agent" "$HOME/.claude/agents/$(basename "$agent")"
done

echo ""
echo "Ensuring scripts are executable..."
chmod +x "$DOTFILES_DIR/claude/statusline.sh"
chmod +x "$DOTFILES_DIR/claude/hooks/detect-docker.sh"

echo ""
echo "Shell integration..."
SHELL_LINE='[ -f ~/dotfiles/shell/functions.sh ] && source ~/dotfiles/shell/functions.sh'

if [ -f "$HOME/.zshrc" ]; then
  if grep -qF "$SHELL_LINE" "$HOME/.zshrc"; then
    echo "  ✓ ~/.zshrc already sources functions"
  else
    echo "" >> "$HOME/.zshrc"
    echo "# Dotfiles shell functions" >> "$HOME/.zshrc"
    echo "$SHELL_LINE" >> "$HOME/.zshrc"
    echo "  → added source line to ~/.zshrc"
  fi
else
  echo "  ! No ~/.zshrc found, skipping shell setup"
fi

# ─── Self-harness (daily proposal loop) ──────────────────────────────────
echo ""
echo "Setting up self-harness..."
if ! has sqlite3; then
  echo "  ! sqlite3 not found — skipping self-harness setup."
else
  # macOS has no `timeout`(1) — it's a GNU coreutils command. self-harness
  # needs it to bound the claude -p calls, so pull in coreutils for `gtimeout`.
  if ! has gtimeout; then
    if has brew; then
      echo "  → installing coreutils (for gtimeout)"
      brew install coreutils
    else
      echo "  ! Homebrew not found — install coreutils manually for gtimeout, or self-harness's claude -p calls won't time out."
    fi
  else
    echo "  ✓ coreutils (gtimeout) present"
  fi

  chmod +x "$DOTFILES_DIR"/claude/self-harness/*.sh
  mkdir -p "$HOME/.claude/self-harness"
  sqlite3 "$HOME/.claude/self-harness/harness.sqlite" < "$DOTFILES_DIR/claude/self-harness/schema.sql"
  echo "  ✓ harness.sqlite ready at $HOME/.claude/self-harness/harness.sqlite"

  PLIST_DST="$HOME/Library/LaunchAgents/com.alexander.claude-self-harness.plist"
  link "$DOTFILES_DIR/claude/self-harness/com.alexander.claude-self-harness.plist" "$PLIST_DST"
  launchctl bootstrap "gui/$(id -u)" "$PLIST_DST" 2>/dev/null || launchctl load "$PLIST_DST" 2>/dev/null || true
  echo "  ✓ LaunchAgent installed — runs daily at 09:00 (or on wake, if the Mac was asleep)"

  if [ ! -f "$HOME/.claude/self-harness/slack-webhook.txt" ]; then
    echo "  ! create $HOME/.claude/self-harness/slack-webhook.txt with your Slack Incoming Webhook URL to enable notifications"
  fi
fi

echo ""
echo "Done. Open a new terminal session for shell changes to take effect."
echo ""
echo "Next steps:"
echo "  1. Create ~/.claude/self-harness/slack-webhook.txt with your Slack Incoming Webhook URL."
echo "  2. Review proposals anytime with ~/dotfiles/claude/self-harness/review.sh"
