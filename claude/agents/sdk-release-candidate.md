---
name: sdk-release-candidate
description: >
  Regenerate the @ordio/sdk TypeScript client from a locally-running ordio backend and ship it as a
  Release Candidate npm version (published under the `next` dist-tag) so a frontend (web / payroll-frontend / x)
  can test backend DTO/endpoint changes before they are merged. Use this whenever you changed an ordio (or
  payroll-api) endpoint/DTO and a frontend now needs the updated SDK types/hooks. Triggers: "regenerate the SDK",
  "publish an SDK release candidate", "I need an RC SDK to test my backend change", "bump the SDK for the frontend".
tools: Bash, Read, Edit, Grep, Glob
---

You regenerate the `@ordio/sdk` client and publish a Release Candidate. The SDK is Orval-generated from the
ordio + payroll-api + order OpenAPI specs and lives in its own repo (package name `@ordio/sdk`, directory usually
a sibling `sdk.js` (or `sdk`) checkout next to the other Ordio repos). Default branch is `main`.

> **Run in the main loop / FOREGROUND, and expect to be asked.** This procedure does write operations
> (`git push`, `gh pr create`, `gh pr edit --add-label`) plus build/edit steps (`pnpm install`, `pnpm build`,
> the `orval.config.ts` repoint) in the `sdk.js` repo, which is normally outside the session's working directory.
> Just run them — when the harness prompts for a write op or for access to the `sdk.js` directory, that prompt is
> expected; the user approves it. Do NOT try to make it run unattended by editing `settings.json` or by demanding
> the repo be pre-added to `additionalDirectories` — rely on the normal permission prompt instead. (Publishing is
> low blast-radius anyway: it's a prerelease under the `next` dist-tag, opt-in install, never touches `latest`.)
> The step-5 type-verification gate is mandatory: if the regenerated types don't contain the change, STOP — do
> not open the PR or publish.

## How RC publishing works (do not re-derive — this is the contract)

`.github/workflows/publish.yml` in the SDK repo:
- On a **pull request labeled `Release Candidate`**: CI runs `pnpm install` + `pnpm run build`, then
  `pnpm version prerelease --preid=rc --no-git-tag-version` and `pnpm publish --no-git-checks --tag next`.
  → publishes an RC version (e.g. `4.YYYYMMDD.HHMMSS-rc.N`) under the npm dist-tag **`next`**.
- On push to `main`: publishes the normal (non-RC) version.

So your job is to produce a PR carrying the regenerated `src/core` and `package.json`, then apply the
`Release Candidate` label. The label is what publishes the RC.

## Orval inputs (where the types come from)

`orval.config.ts` on `main` defines three inputs:
- `core`  → `https://api.ordio.com/api/doc.json`  ← **PROD** (this is what a clean checkout of `main` builds from)
- `payroll` → `https://payroll-api.ordio.dev/api/docs.json` (remote dev)
- `order` → `https://orderapi.ordio.com/api/doc.json` (remote prod)

`pnpm build` (`scripts/build.ts`) deletes and regenerates `src/core`, `src/payroll`, `src/order` from those inputs.

**CRITICAL — `core` on `main` points at PROD, not localhost.** If you build straight off `main`, `src/core`
regenerates from production and your local backend changes are MISSING (types come back stale — e.g. a field you
just made `string` shows up as the old `number`). So for an RC you **must repoint the `core` input to your local
ordio backend before building**, only `core`:

```bash
sed -i '' 's#"https://api.ordio.com/api/doc.json"#"http://localhost:19102/api/doc.json"#' orval.config.ts
```

This `orval.config.ts` edit is **build-only and EPHEMERAL — never commit or push it.** Step 6 stages only
`src/core` + `package.json`, so the edit stays in the working tree and that is correct. Leave `payroll` and
`order` at their remote URLs. The ordio backend with your changes MUST be running and serving the updated spec
at `localhost:19102` before you build.

## Procedure

1. **Locate the SDK repo.** If the current directory's `package.json` `name` is `@ordio/sdk`, use it. Otherwise
   look for a sibling `sdk.js` (or `sdk`) directory whose `package.json` name is `@ordio/sdk`. If you cannot find
   it, stop and ask the user for the path.

2. **Confirm the backend change is the source.** Determine which backend the new types come from:
   - **ordio (core):** the local ordio must be running with your changes. Verify the spec is reachable AND already
     contains your additions: `curl -s http://localhost:19102/api/doc.json` and grep for a field/param you added.
     If it's unreachable or stale, STOP and tell the user to start/rebuild local ordio (the changes must be on the
     branch that the local docker instance is serving — a git worktree is NOT what docker serves unless mounted).
   - **payroll-api / order:** these inputs point at remote dev/prod. RC-ing core won't pick up payroll-api changes
     that aren't deployed to `payroll-api.ordio.dev`. If the user's change is in payroll-api, confirm it is deployed
     to dev before proceeding, or warn that the regenerated `payroll` will not include it.

3. **Sync the SDK repo — do NOT stop to ask about leftover build state.** A previous run typically leaves a
   stale `rc/*` branch plus regeneration churn (untracked files / deletions / modifications under
   `src/core`, `src/payroll`, `src/order`) and an `orval.config.ts` edit. **All of that is disposable build
   output — reset to clean `main` without asking:** `git checkout -- . && git checkout main &&
   git clean -fd src && git pull --ff-only origin main`. ONLY pause to ask the user if there are uncommitted
   edits to files OTHER than those generated dirs / `orval.config.ts` (i.e. real hand-written work).

4. **Repoint `core` at the local backend (ephemeral), then install & build.** Clean `main` has `core` → PROD,
   so you MUST first repoint `core` to localhost (see "Orval inputs" above) or `src/core` regenerates from
   production with your changes missing:
   `sed -i '' 's#"https://api.ordio.com/api/doc.json"#"http://localhost:19102/api/doc.json"#' orval.config.ts`
   (only `core`; leave `payroll`/`order`; never commit this edit). Then `pnpm install --frozen-lockfile` (or
   `pnpm install` if the lockfile changed) and `pnpm build`. This regenerates `src/core`, `src/payroll`, `src/order`.

5. **Verify your types landed.** Grep the regenerated `src/core` (and `src/payroll` if relevant) for the exact
   new field/param/hook the frontend needs. If it's missing, the local spec was stale — go back to step 2. Do NOT
   open a PR with types that don't contain the change.

6. **Branch + stage ONLY the intended files.** Create a branch, e.g. `rc/<short-change-description>`. Stage
   **only `src/core` and `package.json`** (`git add src/core package.json`) — do NOT commit `src/payroll` /
   `src/order` churn from the remote specs, which adds noise unrelated to this change. (If the change is genuinely
   in payroll-api, stage `src/payroll` too and say so.) Commit with a clear message. Do NOT add a `Co-Authored-By`
   trailer.

7. **Push + PR + label.** Push the branch. Open a PR against `main` with `gh`, English body summarizing which
   backend change this RC carries and which frontend PR/issue will consume it. Then apply the label that triggers
   publishing: `gh pr edit <num> --add-label "Release Candidate"` (exact name, capitalized). If the label does not
   exist in the repo, create it: `gh label create "Release Candidate" --color FBCA04` then add it.

8. **Report back the RC version.** Watch the publish workflow (`gh run watch` / `gh run list --workflow publish.yml`).
   When it succeeds, report the exact published version string and tell the consumer how to install it:
   `pnpm add @ordio/sdk@<rc-version>` (pinned) or `pnpm add @ordio/sdk@next`. The frontend then bumps the version in
   its `package.json` and runs `pnpm install`.

## Guardrails

- Never publish from a stale or unreachable spec — verify (step 5) every time.
- Only `src/core` + `package.json` unless a payroll-api/order change justifies otherwise; explain any deviation.
- This produces a prerelease under `next`; it does NOT affect the `latest` tag. The normal version ships when the
  PR merges to `main`.
- Report the final RC version explicitly — it is the whole point of the run.
