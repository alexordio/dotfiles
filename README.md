# dotfiles

My personal Claude Code setup, shell functions, and assorted dev environment config. Mostly for my own backup, but feel free to crib anything useful.

## What's here

claude/ Claude Code config: CLAUDE.md, settings, agents, hooks, statusline
claude/self-harness/ Daily self-improvement loop (see below)
shell/ Shell functions sourced from .zshrc
install.sh Idempotent bootstrap script

## Highlights

- **`CLAUDE.md`** — global preferences. Critical-by-default, plan-before-implement, prefers `gh`/`rg`/`fd`.
- **`settings.json`** — Sonnet by default, `acceptEdits` mode, granular permissions allowlist tuned for Symfony + Docker Compose workflows. ~120 read-only commands pre-allowed (git, docker, gh, pnpm, composer, common shell tools) so the agent can explore codebases without prompting.
- **`statusline.sh`** — repo name, model, context %, session cost, 5h rate limit. Color-coded.
- **`hooks/detect-docker.sh`** — `SessionStart` hook that detects `docker-compose.yml` and tells Claude to prefix PHP/Composer commands with `docker compose exec`.
- **`hooks/auto-approve` (external)** — `PreToolUse` hook that auto-approves compound bash commands (pipes, `&&`, subshells) when every segment is in the allow-list. See [Permission auto-approve hook](#permission-auto-approve-hook) below.
- **`agents/`** — three custom subagents tuned for backend work:
  - `doctrine-architect` (Opus) — entity design, migrations, query performance
  - `ordio-pr-reviewer` (Sonnet) — reviews diffs against `REVIEW.md` + `CLAUDE.md` + standards repo
  - `symfony-debugger` (Sonnet) — root-cause investigation, evidence-first
- **`shell/functions.sh`** — `commit()` generates commit messages from staged diffs using `claude -p`.
- **`self-harness/`** — daily loop (LaunchAgent, 09:00) that mines new Claude Code sessions in Ordio repos for recurring friction and drafts narrow proposals — edits to my skills/subagents/CLAUDE.md, to the shared `ordio-standards` constitution, or personal gitignored per-repo notes (`CLAUDE.local.md`, `.claude/skills|agents`). Never auto-applies anything: proposals land as local branches (or plain files for the personal case) and I review/accept/reject with `self-harness/review.sh`. Notifies via Slack webhook when there's something to look at.

## Install

```bash
git clone https://github.com/alexordio/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

The install script is idempotent. Existing files at the destination paths are backed up with a timestamp suffix, never overwritten silently.

It also:

- Installs Homebrew dependencies (`bash` 4+, `shfmt`, `jq`) needed by the auto-approve hook.
- Clones the auto-approve hook to `~/.claude/auto-approve/` (or `git pull`s it if already present).
- Creates `~/.claude/settings.local.json` from a template if it doesn't exist (see next section).

## Personal vs portable settings

`claude/settings.json` in this repo is **portable**: it contains permission rules for commands (allow/deny/ask), hooks, plugins, and statusline config. No usernames, no machine-specific paths.

Personal stuff (the directories where _your_ projects live, that Claude is allowed to `Read`) goes in `~/.claude/settings.local.json`, which Claude Code automatically merges with the main `settings.json`. This file is **not** in the repo.

The install script seeds it from `claude/settings.local.example.json`. After install, edit it to match your machine:

```jsonc
{
  "permissions": {
    "allow": [
      "Read(//Users/yourname/code/**)",
      "Read(//Users/yourname/work/**)",
      "Read(./**)",
    ],
    "deny": [
      "Read(//Users/yourname/.ssh/**)",
      "Read(//Users/yourname/.aws/**)",
      "Read(**/.env)",
      "Read(**/.env.*)",
    ],
  },
}
```

## Permission auto-approve hook

Claude Code's permission matcher has a long-standing bug ([anthropics/claude-code#13340](https://github.com/anthropics/claude-code/issues/13340)): compound commands like `find … | xargs grep | grep -v node_modules` prompt for approval even when every component (`find`, `xargs`, `grep`) is in the allow-list. With 5–6 parallel Claude Code instances, this gets old fast.

The fix: a `PreToolUse` hook from [oryband/claude-code-auto-approve](https://github.com/oryband/claude-code-auto-approve) that parses bash commands with `shfmt`, walks the AST, and checks each subcommand against your existing `permissions.allow`. If every segment matches, it auto-approves. Otherwise it falls through to Claude Code's normal flow (which still respects your `deny` list).

### Installation

Handled by `install.sh`. If you want to do it manually:

```bash
brew install bash shfmt jq                    # macOS ships bash 3.2; the hook needs 4+
git clone https://github.com/oryband/claude-code-auto-approve.git ~/.claude/auto-approve
chmod +x ~/.claude/auto-approve/approve-compound-bash.sh
```

The hook is registered in `claude/settings.json`:

```jsonc
"hooks": {
  "PreToolUse": [{
    "matcher": "Bash",
    "hooks": [{
      "type": "command",
      "command": "~/.claude/auto-approve/approve-compound-bash.sh",
      "timeout": 3
    }]
  }]
}
```

### Verify it works

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
  | ~/.claude/auto-approve/approve-compound-bash.sh
```

Should output:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
```

If it outputs nothing, the hook is silently aborting. Most likely cause on macOS: missing modern bash. Run `brew install bash` and retry.

### Safety notes

- The hook only auto-approves when **every** segment of a compound command is in `permissions.allow`. One unknown segment → falls through to normal prompting.
- The `deny` list always wins. The hook can't override `Bash(rm -rf:*)` or `Bash(git push --force:*)`.
- `~/.claude/auto-approve/` is a clone of an upstream repo, not symlinked from this dotfiles repo. The install script `git pull`s it on each run.

## Inspirations

This setup borrows ideas from:

- [Freek Van der Herten's dotfiles](https://github.com/freekmurze/dotfiles) — overall structure, `commit()` function pattern
- [Boris Cherny's public Claude Code workflow](https://howborisusesclaudecode.com/) — plan mode discipline, lessons-as-rules
- [Armin Ronacher on agentic coding](https://lucumr.pocoo.org/2025/6/12/agentic-coding/) — tool design principles, simplicity bias
- [oryband/claude-code-auto-approve](https://github.com/oryband/claude-code-auto-approve) — the compound-bash auto-approve hook

## License

MIT — do whatever.
