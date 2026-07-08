---
name: sdd
description: "Spec-Driven Development hub. Entry point for the 5-step SDD workflow. Detects which step the user is on by inspecting existing artifacts (.claude/metadata/ for research docs, .claude/plans/ for plan files, open PR for current branch) and recommends the next step. Use when: (1) User types /sdd, (2) User asks what's next in SDD, (3) User wants to know where they are in the spec-driven workflow."
---

# Spec-Driven Development (`/sdd`)

You are the SDD workflow hub. Detect the current step, show the full workflow, and guide the user to the next one.

## The 5 Steps

| # | Step | Skill | Output |
|---|------|-------|--------|
| 1 | Research Codebase | `/research-codebase` | `.claude/metadata/YYYY-MM-DD_*_topic.md` |
| 2 | Feature Research | `/feature-research` | `.claude/metadata/YYYY-MM-DD_*_topic.md` |
| 3 | Create Plan | `/create-plan` _or_ `/create-vertical-plan` | `.claude/plans/*.md` |
| 4 | GitHub PR Description | `/gh-pr-description` | PR body updated on GitHub |
| 5 | Grill with Docs | `/grill-with-docs` | Validation against docs |

Steps 1 and 2 are often used together: `/research-codebase` for quick codebase orientation, `/feature-research` for full cooperative design with approach selection.

Step 3 has two shapes — pick by how the work should ship:
- **`/create-plan`** — horizontal *phases* (Phase 1 = all backend, Phase 2 = all frontend …). Default for single-layer or "build it all then test" work.
- **`/create-vertical-plan`** — vertical *slices*, each cutting every layer/repo for one increment that ships and verifies on its own. Prefer it for cross-repo / multi-layer work you want to build and validate piece by piece, or when re-cutting a stalled horizontal plan. When recommending step 3, offer both and ask which shape fits.

## Detection Logic

Run these checks **in order** to determine the current step:

**Check 1 — Open PR on current branch**
```bash
git rev-parse --abbrev-ref HEAD
gh pr view --json number,title,url 2>/dev/null
```
If a PR exists → user is at step 4 or 5.

**Check 2 — Plan files**
```bash
ls .claude/plans/ 2>/dev/null
```
If plan files exist → step 3 is done, user is at step 4.

**Check 3 — Research / metadata files**
```bash
ls .claude/metadata/ 2>/dev/null
```
If research docs exist → step 1–2 is done, user is at step 3.

**Check 4 — Nothing found** → User is at step 1.

## Output Format

```
SDD Workflow — payroll-frontend · feat/my-feature

  ✓ 1. Research Codebase     2026-05-26_10-00-00_companies.md
  → 2. Feature Research      ← you are here
    3. Create Plan
    4. GitHub PR Description
    5. Grill with Docs

Ready to run /feature-research?
```

Rules:
- Show `✓` for completed steps (artifact found).
- Show `→` for the recommended next step.
- Show the artifact filename next to completed steps (short, no path).
- If multiple artifacts exist for a step, show the most recent one.
- If a PR exists, show its number and title next to step 4.
- End with a single question: "Ready to run `/skill-name`?" — wait for confirmation before invoking.
- Once the user confirms, invoke the skill via the Skill tool. Pass any arguments through.
- Do not run any step automatically without confirmation.

## Edge Cases

- **Skipped step**: has research but no plan, yet PR already open → show PR at step 4 as `→`, note "plan not found — you may have skipped step 3."
- **Jump to specific step**: `/sdd 3` or `/sdd create-plan` → invoke `/create-plan` immediately.
- **Fresh repo / no .claude dir**: start at step 1 and briefly explain the SDD workflow.
