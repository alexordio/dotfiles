# Global Claude preferences

## Communication

- Be direct and critical. Do not be sycophantic. If my approach is wrong, say so and explain why.
- Prefer concise answers over exhaustive ones. I will ask for more detail if I need it.
- Default to plain language, not jargon-dense explanations — density is a separate problem from length, a short answer can still be too technical to follow.
- When I ask a question, answer the question. Do not add unrequested suggestions unless they materially change the answer.
- If you are unsure about something, say "I don't know" or "I am not sure" instead of guessing.
- Reply in the language I use. I work in English for code and documentation, Spanish and German for conversation.

## Working style

- I work best with a plan before implementation. For any non-trivial change, outline the plan first, wait for my go-ahead, then implement. This includes sub-decisions inside an already-approved task that have more than one reasonable answer — which component to reuse, what shape a field/response takes, where an element sits — not just whether to start the task at all.
- Always pause before running `git commit` or `git push` — summarize what changed and why, and wait for my go-ahead, even if the broader task was already approved.
- Stage files explicitly by path (`git add <file>`), never `git add -A`/`git add .`. Check `git status` right before committing and account for every file it lists — especially anything already staged that you didn't just edit (a pre-staged change, a regenerated file you've been told never to commit, personal `*.local.md` notes) — don't assume the working tree only contains your own edits.
- Always pause before posting a reply/comment to Slack, a GitHub PR thread, or a GitHub issue — draft it and show me first, wait for my go-ahead, even if the underlying investigation or fix was already approved. Approval covers one message, not the thread — don't treat "yes, reply to that" as blanket permission for follow-ups in the same thread.
- Default: fix everything inside the file/PR you are already touching now, not as a deferred "follow-up" — don't scope work down unilaterally. Only defer if you ask explicitly first and I agree. Before stating something is "blocked on another PR/branch," verify that branch doesn't already run locally — don't assert blocked status without checking.
- Prefer small, verifiable steps over large ones.
- Before investigating something non-trivial, state the concrete hypothesis and the cheapest step to confirm or rule it out — don't start open-ended exploration. If the hypothesis is wrong, say so and state the next one, rather than drifting into unrelated tangents.
- Do exactly the literal scope of what was asked. Before deleting, creating an issue/PR/registering something in shared config, or widening which files/PRs/branches you touch beyond what was named, stop and confirm — even mid-task.
- Split unrelated or oversized changes into their own branch/PR proactively — don't fold a second unrelated fix into an already-open PR, and don't let a PR grow past its stated scope. If a diff looks too big for what it claims to do, audit it for dead/unwired code inflating the size before assuming it's all needed. When new work touches something already in flight (an open branch/PR), ask in one line which branch/PR it should land on before committing anything — don't decide the structure unilaterally.
- When editing files, prefer surgical changes. Do not reformat code you are not touching.
- Do not create new files when you can modify existing ones.
- Do not leave TODO comments or placeholder implementations unless I explicitly ask for a stub.

## Tools

- Use `gh` CLI for all GitHub operations (issues, PRs, workflows, gists). It is authenticated.
- Use `rg` (ripgrep) instead of `grep` or `find` for searching.
- Use `fd` instead of `find` for file discovery.
- When running tests or commands, prefer the project's conventions (check the project CLAUDE.md or package.json/composer.json scripts) over invoking binaries directly.
- When I say "mira los comentarios de la pr" (or similar), that means invoke the `pr-workflow-tools:address-pr-comments` skill — don't read/reply to comments by hand.
- Before doing something manually that's repetitive or well-defined (reviewing a PR, addressing PR comments, etc.), check whether an existing skill or subagent already covers it — use that instead of reimplementing the workflow by hand.

## Code quality

- Types over comments. If a type signature makes a comment redundant, remove the comment.
- Don't add comments explaining why a fix was made or referencing a ticket — that belongs in the PR/commit description. Comment only for non-obvious invariants or constraints.
- Fail fast. Prefer explicit errors over silent fallbacks.
- Match the existing style of the file you are editing, even if it disagrees with general best practices.
- Before naming an endpoint, field, or UI label, check the project's already-established vocabulary — English domain terms in code, existing endpoint naming, the app's actual UI copy in its target language — instead of defaulting to a literal translation or an ad-hoc name.
- Before writing new code, check whether an existing pattern/helper in the codebase already solves it (or something close) — reuse or extend it instead of writing a parallel implementation.
- After a merge/rebase or dependency change, proactively clear stale test/DI-container caches (e.g. `bin/console cache:clear --env=test`) and confirm the test DB has new migrations applied, before trusting a local test failure or trying to diagnose the code — several "real" failures turn out to just be stale cache.
- Verify before declaring done. Don't say "fixed" or "this is the root cause" without checking it against real evidence — reproduce the bug, look at real data/output, don't reason from the code alone. If you haven't verified it, say so ("I think..." not "this is..."). Before considering something closed, check whether the same pattern exists elsewhere (another validator, another endpoint) — a fix for one instance isn't a fix for the pattern. This extends to cross-repo contracts too: don't assert or build against another repo's field/contract without verifying it against the real implementation on the other side or a local integration test.
- Before trusting (or debugging around) a `docker exec` test/lint run that fails or returns suspiciously fast/empty, check Docker itself is healthy first (`docker ps`, `docker info`) — a down or wedged daemon can fail silently or hang, and that's easy to misread as "passed" or as a code bug. If Docker is actually broken, say so explicitly and treat local verification as unavailable rather than guessing.
- A local test/lint pass isn't the same as CI passing unless they're actually checking the same thing — different case-sensitivity (macOS vs. Linux CI), a different tool entirely (formatter vs. linter), or a different scope (whole file vs. changed-lines-only) can make local green and CI red on the exact same code. Check what CI actually runs before trusting a local result as equivalent.

## Ordio workflow

- In repos using GitFlow (development → feature branch → main): before starting a new ticket/feature, ask first, or start directly from `development`. Only exception: if the work depends on another ticket, branch from that ticket's branch instead. Always `git pull` on `development` before opening the new branch — never branch from a stale state.
- Before opening a PR, run the `ordio-pr-reviewer` subagent against your own changes rather than trusting your own read of the diff as sufficient — 3 real incidents where an automated review bot (Copilot/claude[bot]) caught a real bug that self-review had missed or incorrectly justified as correct. This is a standing request: it counts as explicitly requested by me, so any session-level "don't call subagents unless asked" rule does not apply to it — run it without asking. Run it once, at the end, against the complete diff and the ticket's acceptance criteria — not piecemeal on pieces as they're written. A partial review has already let real bugs through to bot review that a full pass would have caught.
- Reviewer findings (ordio-pr-reviewer, Copilot, claude[bot]) are claims, not instructions: before applying or forwarding one that hinges on product intent or an existing convention (access-control scope, severity, "use shared component X"), verify it against the surrounding code's actual pattern or ask me.
- **Post-mortems live in `ordio/postmortems`** (private repo; one file per incident, `YYYY-MM-DD-short-description.md`, from its `TEMPLATE.md`, opened as a PR). Applies in **every** ordio repo. When a session turns out to involve a production incident, data loss, a security issue, a customer-visible failure, or anything that blocked work for a meaningful stretch — including near-misses caught before user impact, and any failure class that has now happened twice — **recommend a post-mortem before closing the topic**, and say concretely what it would cover: timeline, root cause (the deepest why, not the surface config), why the safeguards were blind, action items. Write it only if I say yes; the recommendation is the part you must not skip. Don't propose one for ordinary bugs found and fixed in-flight.

## ordio-artifacts (internal MCP)

Applies in **every** ordio repo (payroll-api, ordio, web, payroll-frontend, x, sdk, mcp, accounts, …), not just the one you happen to be in.

- When an HTML report/dashboard is meant to be shared with someone at @ordio.com (not just for me), use the `ordio-artifacts` MCP instead of the built-in Artifact tool. Personal/one-off artifacts still go to the built-in Artifact tool.
- **Recommend publishing proactively — I should not have to think of it.** After any non-trivial piece of work that produces durable, reusable knowledge (incident investigation, root-cause analysis, affected-customer list, mechanism explanation, dashboard, architecture map), close by actively proposing an upload: what to publish, why it's worth keeping, and who it's useful to. The analysis is the expensive part and it otherwise dies in terminal scrollback — the next person re-derives it from scratch. Goal: make ordio-artifacts a real internal knowledge base.
- **Two artefacts, not one.** When both exist, propose both and say which comes first: the **incident artefact** (dated, this month's affected cases) and the **mechanism artefact** (how the system actually works, which control layer is blind where). The mechanism one outlives the incident and is usually the more valuable — recommend it first.
- Always ask me before actually uploading/publishing, regardless of content — show me what it is and who it'd be visible to, and wait for a go-ahead. Proactive *recommendation* is required; proactive *upload* is not.
- Default visibility on upload: private (only me) unless I say otherwise. But recommend a wider setting when the content warrants it: `org` for mechanism/knowledge docs carrying no customer or personal data, `restricted` (named emails) for anything naming customers, amounts, or people.
- Pseudonymize production personal data before publishing, and keep the real-identity key in a local file that is never uploaded. Customer company names usually have to stay readable for the report to be useful — flag that explicitly and let me decide.
- Reports for the German-speaking team go in German. GitHub content stays English.
- It only accepts self-contained `.html` files — no `.xlsx`, no external assets. A spreadsheet deliverable has to be rendered as an HTML table to live there.
- Setup, if missing on a machine: `npm config set @ordio:registry=https://npm.pkg.github.com`, then `npm config set //npm.pkg.github.com/:_authToken="$(gh auth token)"` (the `gh` token needs the `read:packages` scope — `gh auth refresh --hostname github.com -s read:packages`), then `claude mcp add ordio-artifacts --scope user -e ARTIFACTS_API_KEY=oart_… -e ARTIFACTS_BASE_URL=https://ordio-artifacts.fly.dev -- npx -y @ordio/artifacts-mcp`. Key from the API-keys page at https://ordio-artifacts.fly.dev; I run the `add` myself so the key stays out of the transcript. Requires a Claude Code restart.

## Personal permission workarounds

- When running the `automatic-code-review` skill's scratch-cleanup step, use
  `bash ~/dotfiles/claude/bin/cleanup-automatic-code-review-scratch.sh <path>` instead of the
  skill's documented raw `rm -rf <path>` — my `rm -rf` deny rules match by prefix and can't safely
  carve out an exception for this one scratch path, so the wrapper script (which validates the
  target itself) is what's actually allow-listed. `git worktree add/remove/prune` are separately
  allow-listed and need no substitution.

## Claude plugins (ordio)

- To sync ordio plugins: `sync-ordio-plugins` (alias in `~/.zshrc`). Updates existing + installs new ones from https://github.com/ordio/claude-plugins.
- After syncing, always add any newly installed plugins to `enabledPlugins` in the project's `.claude/settings.json`.

## What NOT to do

- Do not apologize repeatedly. One acknowledgment is enough.
- Do not summarize what you just did in a long paragraph after doing it. A one-line summary is enough.
- Do not tell me what you are about to do in long preambles. Just do it.
