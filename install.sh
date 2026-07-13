#!/usr/bin/env bash
# install.sh — bootstrap dotfiles on a new machine
# Idempotent: safe to re-run anytime.

set -euo pipefail

DOTFILES_DIR="${HOME}/dotfiles"
AUTO_APPROVE_DIR="${HOME}/.claude/auto-approve"
AUTO_APPROVE_REPO="https://github.com/oryband/claude-code-auto-approve.git"

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
link "$DOTFILES_DIR/claude/ccx.sh"                       "$HOME/.claude/ccx.sh"
link "$DOTFILES_DIR/claude/hooks/detect-docker.sh"       "$HOME/.claude/hooks/detect-docker.sh"

mkdir -p "$HOME/.claude/plugins/cache/personal"
link "$DOTFILES_DIR/claude/personal-plugin"              "$HOME/.claude/plugins/cache/personal/personal"

for agent in "$DOTFILES_DIR"/claude/agents/*.md; do
  [ -f "$agent" ] || continue
  link "$agent" "$HOME/.claude/agents/$(basename "$agent")"
done

echo ""
echo "Ensuring scripts are executable..."
chmod +x "$DOTFILES_DIR/claude/statusline.sh"
chmod +x "$DOTFILES_DIR/claude/hooks/detect-docker.sh"

# ─── Claude Code auto-approve hook ────────────────────────────────────────
# Auto-approves compound bash commands (pipes, &&, ||) when every segment
# is in the allow-list. Workaround for github.com/anthropics/claude-code#13340.
echo ""
echo "Setting up auto-approve hook..."

# 1. Dependencies
if ! has brew; then
  echo "  ! Homebrew not found — install from https://brew.sh and re-run"
  echo "    Skipping auto-approve hook setup."
else
  # macOS ships bash 3.2; the hook needs bash 4+
  if [ ! -x /opt/homebrew/bin/bash ] && [ ! -x /usr/local/bin/bash ]; then
    echo "  → installing modern bash (macOS ships 3.2, hook needs 4+)"
    brew install bash
  else
    echo "  ✓ modern bash present"
  fi

  for dep in shfmt jq; do
    if ! has "$dep"; then
      echo "  → installing $dep"
      brew install "$dep"
    else
      echo "  ✓ $dep present"
    fi
  done
fi

# 2. The hook itself (cloned, not symlinked — it's a third-party repo)
if [ -d "$AUTO_APPROVE_DIR/.git" ]; then
  echo "  ✓ auto-approve already cloned — pulling latest"
  git -C "$AUTO_APPROVE_DIR" pull --quiet --ff-only || \
    echo "  ! could not fast-forward auto-approve (local changes?). Skipping pull."
else
  echo "  → cloning auto-approve to $AUTO_APPROVE_DIR"
  git clone --quiet "$AUTO_APPROVE_REPO" "$AUTO_APPROVE_DIR"
fi

chmod +x "$AUTO_APPROVE_DIR/approve-compound-bash.sh" 2>/dev/null || true

# 3. Quick smoke test
if [ -x "$AUTO_APPROVE_DIR/approve-compound-bash.sh" ]; then
  result=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
    | "$AUTO_APPROVE_DIR/approve-compound-bash.sh" 2>/dev/null || true)
  if echo "$result" | grep -q '"permissionDecision":"allow"'; then
    echo "  ✓ auto-approve hook working"
  else
    echo "  ! auto-approve hook installed but smoke test did not pass."
    echo "    Run manually to debug:"
    echo "      bash -x $AUTO_APPROVE_DIR/approve-compound-bash.sh <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}'"
  fi
fi

# ─── Personal settings.local.json ────────────────────────────────────────
# settings.json (in dotfiles) is portable. Per-user paths (Read rules for
# your project directories) live in settings.local.json, which is NOT in
# the repo. Claude Code merges both automatically.
LOCAL_SETTINGS="$HOME/.claude/settings.local.json"
TEMPLATE="$DOTFILES_DIR/claude/settings.local.example.json"

echo ""
echo "Personal settings (settings.local.json)..."
if [ -f "$LOCAL_SETTINGS" ]; then
  echo "  ✓ $LOCAL_SETTINGS already exists — leaving it alone"
elif [ -f "$TEMPLATE" ]; then
  cp "$TEMPLATE" "$LOCAL_SETTINGS"
  echo "  → created $LOCAL_SETTINGS from template"
  echo "    EDIT IT to add your own project paths under permissions.allow."
else
  echo "  ! template not found at $TEMPLATE — skipping"
fi

# ─── Shell integration ───────────────────────────────────────────────────
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
echo ""
echo "Next steps:"
echo "  1. Edit ~/.claude/settings.local.json with your own project paths."
echo "  2. Restart any open Claude Code sessions to pick up the new config."
