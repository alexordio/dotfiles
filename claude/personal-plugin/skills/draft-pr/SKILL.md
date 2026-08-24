---
name: draft-pr
description: Open PRs as draft, then watch CI in the background and ask before flipping to ready-for-review. Use whenever the user wants to create/open a PR, "publish", or "ship" a branch from the terminal — this replaces creating a PR directly ready-for-review.
---

# Draft PR → watch CI → ready for review

Every PR from the terminal starts in draft. CI is watched in the background; the PR is only flipped to ready-for-review after the user confirms.

## Steps

1. **Commit and push** as usual (group by concern, descriptive branch name, push with `-u` if new).

2. **Open the PR as draft:**
   ```bash
   gh pr create --draft --title "..." --body "..."
   ```
   Write the description the same way you normally would (reuse `gh-pr-description` skill if available).

3. **Watch CI in the background** — do not block the conversation on this. `gh pr checks --watch` can exit clean before GitHub has even registered the checks for this push, or before a late-arriving status check (e.g. codecov/patch) lands — its exit code alone is not proof CI is done:
   ```bash
   gh pr checks <number> --watch --interval 30; echo WATCH_EXITED
   ```
   Run this via a backgrounded Bash call (`run_in_background: true`) right after opening the PR, then continue with whatever else the user is doing.

4. **On completion (you'll get notified):** the watch returning is a cue to re-check, not the answer itself. Always re-run `gh pr checks <number>` fresh (no `--watch`) once it returns, and read the actual per-check states — don't trust the watch's own success/failure. If anything is still pending, treat the watch's exit as inconclusive and re-watch rather than reporting a result.

   CI can take 10+ minutes, so the user is likely not watching the terminal — FIRST send a system push notification with the PushNotification tool so the result actually reaches them (e.g. "CI green on PR #123 — ready for review?" / "CI failed on PR #123: PHPUnit"), THEN post the details in the conversation:
   - **All checks pass (confirmed by the fresh re-query)** → tell the user CI is green and ask if they want it marked ready for review now. Only run `gh pr ready <number>` after they say yes. Never mark ready automatically.
   - **Any check failed** → report which ones (from the fresh re-query) and offer to fix them (the `address-pr-checks` skill if available), or leave it in draft for the user to handle.

## Notes

- This only runs as long as the current Claude Code session stays open — it's not a persistent/cloud job. If the session ends before CI finishes, the watch dies with it; just re-run step 3 when you're back.
- Never mark a PR ready without explicit confirmation, even if CI is green — the user gets a say every time.
