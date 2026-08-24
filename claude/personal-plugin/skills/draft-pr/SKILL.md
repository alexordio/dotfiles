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

3. **Watch CI in the background** — do not block the conversation on this:
   ```bash
   gh pr checks <number> --watch --interval 30 && echo CI_PASSED || echo CI_FAILED
   ```
   Run this via a backgrounded Bash call (`run_in_background: true`) right after opening the PR, then continue with whatever else the user is doing. `gh pr checks --watch` already polls natively — no custom loop needed.

4. **On completion (you'll get notified):** CI can take 10+ minutes, so the user is likely not watching the terminal — FIRST send a system push notification with the PushNotification tool so the result actually reaches them (e.g. "CI green on PR #123 — ready for review?" / "CI failed on PR #123: PHPUnit"), THEN post the details in the conversation:
   - **CI_PASSED** → tell the user CI is green and ask if they want it marked ready for review now. Only run `gh pr ready <number>` after they say yes. Never mark ready automatically.
   - **CI_FAILED** → report which checks failed (`gh pr checks <number>`) and offer to fix them (the `address-pr-checks` skill if available), or leave it in draft for the user to handle.

## Notes

- This only runs as long as the current Claude Code session stays open — it's not a persistent/cloud job. If the session ends before CI finishes, the watch dies with it; just re-run step 3 when you're back.
- Never mark a PR ready without explicit confirmation, even if CI is green — the user gets a say every time.
