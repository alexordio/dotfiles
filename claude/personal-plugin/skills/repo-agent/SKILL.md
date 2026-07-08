---
name: repo-agent
description: >
  Spawn a Claude Code agent ROOTED in another repo (its own CLAUDE.md / .claude config loads natively),
  for real work or cross-repo fan-out. Use when a task needs to edit/build/commit/PR in a sibling repo
  (e.g. from payroll-frontend into ordio, sdk.js, web, accounts, payroll-api) and you want that repo's
  conventions respected — not just file access. Triggers: "do X in the <other> repo", "work across these
  repos", "fan out an agent per repo", "run an agent in ordio/sdk/web".
---

# Rooted repo agent (`repo-agent`)

## When to use this (and when not)

In-session subagents and `permissions.additionalDirectories` give **file access** to sibling repos but do
**not** load the target repo's `CLAUDE.md`/rules/skills/hooks. For substantial work in another repo, root a
process there instead — it loads the repo's full config natively.

- **Quick one-off edit** in a sibling repo, conventions already known → just edit in-session (additionalDirectories covers access); read the target repo's `AGENTS.md`/`CLAUDE.md` first.
- **Real work** (multi-file change, build, tests, commit, push, PR) or **fan-out across repos** → use the rooted agent below.
- **Never** delegate mutations to a *background* in-session subagent — background subagents auto-deny anything that would prompt (git push, pnpm, gh, out-of-workspace edits).

## How to run

Script: `/Users/alexander/dotfiles/claude/personal-plugin/skills/repo-agent/repo-agent.sh`

```bash
bash "/Users/alexander/dotfiles/claude/personal-plugin/skills/repo-agent/repo-agent.sh" <repo> [--yolo] [--model m] [--json] [--add-dir p]... <task...>
```

- `<repo>`: absolute path, or a bare name resolved under `$ORDIO_REPOS_ROOT` (default `~/Desktop/Repos Ordio`) — e.g. `ordio`, `sdk.js`, `web`, `accounts`, `payroll-api`.
- Default mode = `acceptEdits`: edits flow, but commands that would prompt (git push, pnpm, gh pr create) are **denied** in headless mode → use for **investigate + edit, then hand back** (the main session commits/pushes).
- `--yolo` = `--dangerously-skip-permissions`: full autonomy incl. git/pnpm/gh. Only for trusted tasks.
- `--json`: machine output for parsing when orchestrating.

## Patterns

Single rooted task (edit only; you commit/push from the main session afterward):
```bash
bash ".../repo-agent.sh" ordio "Add field X to DTO Y, populate in service Z, add a unit test"
```

Fully autonomous (the rooted agent commits, pushes, opens the PR itself):
```bash
bash ".../repo-agent.sh" sdk.js --yolo "Regenerate src/core against local ordio, branch, commit src/core+package.json, push, open PR labeled 'Release Candidate'"
```

Fan-out — one rooted agent per repo, in parallel (run each with the Bash tool's background mode and collect on completion):
```bash
bash ".../repo-agent.sh" ordio   --yolo "<backend task>"
bash ".../repo-agent.sh" web      --yolo "<frontend task>"
```

## Notes / gotchas
- No `--cwd` flag exists; the script `cd`s into the repo first (so its `.claude` config loads).
- The rooted process loads `~/.claude` global config + the repo's own `.claude`. Its permission decisions follow those settings (plus the mode you pass).
- Auth and MCP load per-process; if a task needs an MCP server, ensure it's configured for that repo (or globally).
- Prefer this over editing through `additionalDirectories` whenever the target repo's conventions matter.
