# dotfiles

My personal Claude Code setup, shell functions, and assorted dev environment config. Mostly for my own backup, but feel free to crib anything useful.

## What's here

claude/ Claude Code config: CLAUDE.md, settings, agents, hooks, statusline
claude/self-harness/ Daily self-improvement loop (see below)
shell/ Shell functions sourced from .zshrc
install.sh Idempotent bootstrap script

## Highlights

- **`CLAUDE.md`** — global preferences. Critical-by-default, plan-before-implement, prefers `gh`/`rg`/`fd`.
- **`settings.json`** — Sonnet by default, `acceptEdits` mode, granular permissions allowlist tuned for Symfony + Docker Compose workflows.
- **`statusline.sh`** — repo name, model, context %, session cost, 5h rate limit. Color-coded.
- **`hooks/detect-docker.sh`** — `SessionStart` hook that detects `docker-compose.yml` and tells Claude to prefix PHP/Composer commands with `docker compose exec`.
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

## Inspirations

This setup borrows ideas from:

- [Freek Van der Herten's dotfiles](https://github.com/freekmurze/dotfiles) — overall structure, `commit()` function pattern
- [Boris Cherny's public Claude Code workflow](https://howborisusesclaudecode.com/) — plan mode discipline, lessons-as-rules
- [Armin Ronacher on agentic coding](https://lucumr.pocoo.org/2025/6/12/agentic-coding/) — tool design principles, simplicity bias

## License

MIT — do whatever.
