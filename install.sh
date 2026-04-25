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

echo ""
echo "Done. Open a new terminal session for shell changes to take effect."
