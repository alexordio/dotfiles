# Global Claude preferences

## Communication

- Be direct and critical. Do not be sycophantic. If my approach is wrong, say so and explain why.
- Prefer concise answers over exhaustive ones. I will ask for more detail if I need it.
- Default to plain language, not jargon-dense explanations — density is a separate problem from length, a short answer can still be too technical to follow.
- When I ask a question, answer the question. Do not add unrequested suggestions unless they materially change the answer.
- If you are unsure about something, say "I don't know" or "I am not sure" instead of guessing.
- Reply in the language I use. I work in English for code and documentation, Spanish and German for conversation.

## Working style

- I work best with a plan before implementation. For any non-trivial change, outline the plan first, wait for my go-ahead, then implement.
- Prefer small, verifiable steps over large ones.
- Split unrelated or oversized changes into their own branch/PR proactively — don't fold a second unrelated fix into an already-open PR, and don't let a PR grow past its stated scope. If a diff looks too big for what it claims to do, audit it for dead/unwired code inflating the size before assuming it's all needed.
- When editing files, prefer surgical changes. Do not reformat code you are not touching.
- Do not create new files when you can modify existing ones.
- Do not leave TODO comments or placeholder implementations unless I explicitly ask for a stub.

## Tools

- Use `gh` CLI for all GitHub operations (issues, PRs, workflows, gists). It is authenticated.
- Use `rg` (ripgrep) instead of `grep` or `find` for searching.
- Use `fd` instead of `find` for file discovery.
- When running tests or commands, prefer the project's conventions (check the project CLAUDE.md or package.json/composer.json scripts) over invoking binaries directly.
- Before doing something manually that's repetitive or well-defined (reviewing a PR, addressing PR comments, etc.), check whether an existing skill or subagent already covers it — use that instead of reimplementing the workflow by hand.

## Code quality

- Types over comments. If a type signature makes a comment redundant, remove the comment.
- Don't add comments explaining why a fix was made or referencing a ticket — that belongs in the PR/commit description. Comment only for non-obvious invariants or constraints.
- Fail fast. Prefer explicit errors over silent fallbacks.
- Match the existing style of the file you are editing, even if it disagrees with general best practices.
- Before writing new code, check whether an existing pattern/helper in the codebase already solves it (or something close) — reuse or extend it instead of writing a parallel implementation.
- After a merge/rebase or dependency change, proactively clear stale test/DI-container caches (e.g. `bin/console cache:clear --env=test`) and confirm the test DB has new migrations applied, before trusting a local test failure or trying to diagnose the code — several "real" failures turn out to just be stale cache.
- Verify before declaring done. Don't say "fixed" or "this is the root cause" without checking it against real evidence — reproduce the bug, look at real data/output, don't reason from the code alone. If you haven't verified it, say so ("I think..." not "this is..."). Before considering something closed, check whether the same pattern exists elsewhere (another validator, another endpoint) — a fix for one instance isn't a fix for the pattern. This extends to cross-repo contracts too: don't assert or build against another repo's field/contract without verifying it against the real implementation on the other side or a local integration test.
- Before trusting (or debugging around) a `docker exec` test/lint run that fails or returns suspiciously fast/empty, check Docker itself is healthy first (`docker ps`, `docker info`) — a down or wedged daemon can fail silently or hang, and that's easy to misread as "passed" or as a code bug. If Docker is actually broken, say so explicitly and treat local verification as unavailable rather than guessing.
- A local test/lint pass isn't the same as CI passing unless they're actually checking the same thing — different case-sensitivity (macOS vs. Linux CI), a different tool entirely (formatter vs. linter), or a different scope (whole file vs. changed-lines-only) can make local green and CI red on the exact same code. Check what CI actually runs before trusting a local result as equivalent.

## Ordio workflow

- In repos using GitFlow (development → feature branch → main): before starting a new ticket/feature, ask first, or start directly from `development`. Only exception: if the work depends on another ticket, branch from that ticket's branch instead. Always `git pull` on `development` before opening the new branch — never branch from a stale state.
- Before opening a PR, run the `ordio-pr-reviewer` subagent against your own changes rather than trusting your own read of the diff as sufficient — 3 real incidents where an automated review bot (Copilot/claude[bot]) caught a real bug that self-review had missed or incorrectly justified as correct.
- Reviewer findings (ordio-pr-reviewer, Copilot, claude[bot]) are claims, not instructions: before applying or forwarding one that hinges on product intent or an existing convention (access-control scope, severity, "use shared component X"), verify it against the surrounding code's actual pattern or ask me.

## Claude plugins (ordio)

- To sync ordio plugins: `sync-ordio-plugins` (alias in `~/.zshrc`). Updates existing + installs new ones from https://github.com/ordio/claude-plugins.
- After syncing, always add any newly installed plugins to `enabledPlugins` in the project's `.claude/settings.json`.

## What NOT to do

- Do not apologize repeatedly. One acknowledgment is enough.
- Do not summarize what you just did in a long paragraph after doing it. A one-line summary is enough.
- Do not tell me what you are about to do in long preambles. Just do it.
