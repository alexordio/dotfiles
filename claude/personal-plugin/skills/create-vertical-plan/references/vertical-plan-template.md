# Vertical-Slice Implementation Plan Template

Use this exact structure for the plan document at `.claude/plans/YYYY-MM-DD_HH-MM-SS_descriptive_name.md`.
Replace bracketed placeholders with real values from your research. Never leave placeholder text in
the final document. The unit of progress is a **vertical slice** — a thin cut through every layer
(and repo) a feature touches that ships and is verifiable on its own.

```markdown
---
title: [Feature/Task Name] — Vertical-Slice Plan
date: [YYYY-MM-DD]
git_commit: [hash]
branch: [branch]
repository: [repo]
structure: vertical-slices
links: [research doc / tickets / prior plan]
tags: [relevant, tags]
---

# [Feature/Task Name] — Vertical-Slice Implementation Plan

## Overview

[1–2 sentences: what's being built, and that it's organised as vertical slices that each ship and
verify on their own.]

## Decisions (resolved during research — no open questions remain)

- [Architectural choice + why. Every decision the slices depend on is made here.]

## Why vertical (and the keystone caveat)

- **End-state invariant:** [the measurable thing that must be true when done — e.g. "one request
  per month", "all writes go through the new store", "single auth path"].
- **Keystone:** [the shared piece the invariant depends on — aggregator / schema / router / single
  source of truth]. This becomes **Slice 0 (spine)**.
- **Spine-first reconciliation:** every later slice *extends* the spine (adds one field/case/route)
  rather than rebuilding or forking it. The spine only grows; the invariant metric only improves.
  This is what stops naive slicing from re-introducing the very problem the work exists to fix.

## Current State (verified)

[What exists now, with `file:line` references. Key constraints discovered.]

## Desired End State

[The measurable invariant(s) and how to verify each.]

## What We Are NOT Doing

[Explicit out-of-scope items.]

## Carry-over (if re-cutting existing work)

Matrix mapping each prior change/fix to the slice that re-delivers it. Nothing gets silently dropped.

| # | Prior change/fix | Where it lives now | Verdict | Re-delivered in |
|---|------------------|--------------------|---------|-----------------|
| 1 | [fix] | [file:line / PR] | survives / re-home / re-implement / obsolete | Slice [N] |

**Base provenance (verify before trusting the matrix):** for each prior change, confirm whether it
is *actually in this plan's base branch*. If it lives in an unmerged or parallel PR, record the
**donor strategy** per source — *merge-first*, *rebase-onto*, *cherry-pick*, or
*won't-merge → take-what's-useful*. A carry-over whose source is not in the base will be silently
re-implemented (duplication) or collide at merge. When re-delivering, fix the **original problem**
each change solved in the new architecture; don't port the workaround if the new design removes its
root cause.

| Donor source | In base branch? | Donor strategy |
|--------------|-----------------|----------------|
| [PR #xxxx] | no — unmerged | won't-merge → take-what's-useful |

## Slice 0 — Spine / keystone

**Goal:** the minimal skeleton of the shared piece + the simplest real increment riding on it
(NOT a "do all the infra" phase).

### Changes
- **[layer/repo]**: [concrete change, `file:line`]
- **[layer/repo]**: [concrete change, `file:line`]

### Success Criteria
#### Verifiable now (no external dependency)
- [ ] [signal checkable immediately on this branch]
#### Gated on [named deploy / SDK RC / contract]
- [ ] [end-to-end signal that only works once the dependency lands]

---

## Slice [N] — [one increment, named by what it delivers]

**Goal:** [the single observable thing this slice ships]

### Changes
- **[layer/repo]**: [concrete change, `file:line`]
- **[layer/repo]**: [concrete change, `file:line`]
  (a real slice lists changes in MORE THAN ONE layer; if it's one layer, re-cut it)

### Carry-over delivered (if any)
- #[n] [prior fix this slice re-homes/finishes]

### Dependencies
- [spine + any specific earlier slice; "none after Slice 0" is the default and the goal]

### Success Criteria
#### Verifiable now (no external dependency)
- [ ] [test or manual signal that fails if this slice's logic breaks]
#### Gated on [named deploy / SDK RC / contract]
- [ ] [the end-to-end signal — ideally a measurable delta in the end-state metric]

> Be honest: a slice gated end-to-end is still valid, but say *what* it's gated on — don't label
> gated work as independently verifiable. When the contract exists but the typed client/deploy lags,
> ship a **marked temporary shim** (e.g. an untyped string literal where the SDK member isn't
> generated yet, with a `// TODO/ponytail:` marker) and **batch the real integration once at the
> end** (e.g. a single SDK regen) rather than per slice.

---

[... more slices, then any independent slices (e.g. correctness) that can interleave anytime ...]

## Sequencing & Dependencies

[Which slices depend on the spine, and any genuine inter-slice ordering. Be honest about the few
real dependencies; most slices should be parallelisable after Slice 0. Note any donor-PR ordering.]

## Cross-repo coordination (if multi-repo)

[Per-slice contract/SDK flow: which backend change each slice needs, how the contract is sent
(broker task / issue), and the SDK-batching decision. Frame each backend request with the original
problem it solves.]

## Testing Strategy

[Per-slice acceptance signal first. State which slices are fully verifiable now vs gated, and on
what.]
```
