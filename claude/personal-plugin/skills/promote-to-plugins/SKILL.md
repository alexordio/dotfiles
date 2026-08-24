---
name: promote-to-plugins
description: >
  Promote a personal agent/skill (dotfiles, ~/.claude, or a project's .claude/) into the shared
  ordio/claude-plugins repo as a proper plugin + PR — not a copy-paste, a team-safe one. Use when
  asked to "publish this as a plugin", "promote X to claude-plugins", "traspasar esto al repo de
  plugins", "make this a team skill/agent", or "share my local agent/skill with the team".
---

# Promote to claude-plugins

Turns a personal-only agent/skill into a plugin the whole team can install via `sync-ordio-plugins`,
opened as a real PR against `ordio/claude-plugins`. Do the full thing without asking for
confirmation at each step — only stop where a guardrail below says to.

Repo root: `$ORDIO_REPOS_ROOT` (default `~/Desktop/Repos Ordio`) `/claude-plugins`.

## Procedure

1. **Locate the source.** Personal agent → `~/.claude/agents/<name>.md` (usually a symlink into
   `~/dotfiles/claude/agents/`). Personal skill → `~/dotfiles/claude/personal-plugin/skills/<name>/`.
   Project-local → the project's `.claude/agents|skills/<name>`.

2. **Audit for team-safety — do not skip.** Grep the source for anything that only holds on this
   machine: absolute `/Users/<me>` paths, personal env vars, ports/URLs that aren't an actual shared
   team convention, "I"/"my" phrasing assuming solo use. Verify each externally-looking fact (a port, a
   URL, a container name) against the real shared source (`docker-compose.yml`, the project's
   `CLAUDE.md`/constitution) instead of assuming it's universal just because it works for you.
   - Generalizable → fix it in the copy.
   - Not generalizable (depends on a personal script/path with no team equivalent) → **stop and say so**
     instead of publishing something that only works on your machine under a team-shared name.

3. **Shape the plugin by precedent.** `rg` `plugins/*/agents` and `plugins/*/.claude-plugin/plugin.json`
   in claude-plugins for something the same shape (agent-only, skill-only, or both) and mirror its
   layout exactly:
   - Agent-only: `plugins/<name>/.claude-plugin/plugin.json` + `plugins/<name>/agents/<name>.md`
     (e.g. `ux-evaluation`, `pr-review-bot`).
   - Skill-only: `plugins/<name>/.claude-plugin/plugin.json` + `plugins/<name>/skills/<name>/SKILL.md`
     (e.g. `release-train`, `product-updates`).
   - If a plugin covering this topic already exists, extend it (bump its `version` — patch/minor per
     the size of the change) instead of creating a new one.
   - `plugin.json` is just `{name, description, version}` — no per-file manifest of agents/skills
     needed, they're auto-discovered by directory.

4. **Register in `.claude-plugin/marketplace.json`** (new plugin only): append an entry —
   `name`, `source: "./plugins/<name>"`, `description`, `version: "1.0.0"`,
   `category` (reuse an existing one — `development`/`productivity`/`testing` — don't invent a new
   one without a real reason), `author: {"name": "Ordio Team"}`.

5. **Branch from a fresh `origin/master` — never from whatever's checked out.** The repo commonly has
   unrelated in-progress/untracked work on the current branch (someone else's plugin-in-progress).
   `git fetch origin && git checkout -b feat/<slug> origin/master`. Untracked files from other
   branches survive this; don't `git clean` them.

6. **Commit, matching the repo's own log style**: `feat(<plugin-name>): <what> (v<version>)`,
   short body explaining it was promoted from personal use to team-shared. No AI attribution trailer
   ([[feedback_no_coauthored]]).

7. **Push + `gh pr create --repo ordio/claude-plugins --base master`.** English body: what it does,
   why it's now team-wide (not just local), a short test-plan checklist (`sync-ordio-plugins` picks
   it up / triggers fire as expected). No CI in this repo to watch — open ready for review unless told
   otherwise.

8. **Report the PR URL.** Don't merge it yourself.

## Guardrails

- Step 2 is the whole point of this skill — a plugin that only works on the author's machine is worse
  than not publishing it, because it fails silently for teammates. Never skip it to save time.
- Never touch another branch's untracked/in-progress files in claude-plugins while doing this.
- Don't invent new `category` values or plugin.json fields beyond what existing plugins use.
