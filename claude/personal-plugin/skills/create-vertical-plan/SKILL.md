---
name: create-vertical-plan
description: >-
  Create an implementation plan organised as VERTICAL SLICES instead of horizontal layer phases.
  Each slice cuts through every layer/repo for one increment, ships independently, and is verifiable
  on its own. Use when the user wants to "build and test a bit at a time", "vertical plan", "vertical
  slices", "incremental/iterative plan", "thin slices", or asks to restructure a horizontal phased
  plan into something they can ship and validate piece by piece. The deliverable is a plan document
  under .claude/plans/, not code.
---

# Create Vertical-Slice Implementation Plan

Produce a plan whose unit of progress is a **vertical slice** — a thin cut through all the layers
(and repos) a feature touches, end-to-end, that delivers one observable increment and can be
shipped and tested on its own. This is the alternative to a horizontal plan (Phase 1 = all backend,
Phase 2 = all frontend …), which forces "test everything at the end".

This skill shares the discipline of `create-plan` (interactive, verify with code, concrete
file:line references, no open questions in the final doc) — it only changes the **decomposition
axis** from layers to slices. If the user wants a layered/phased plan, use `create-plan` instead.

## Core principles

- **Plan, do not code.** Deliverable: `.claude/plans/YYYY-MM-DD_HH-MM-SS_<name>.md`.
- **Verify with code, not assumptions.** Read the real files; cite `file:line`.
- **Iterate with the user.** Confirm the slice list before writing detailed slices.
- **Every slice is independently shippable AND verifiable.** If a "slice" can't be demoed/tested
  without another unmerged slice, it isn't a slice yet — fold or re-cut it.
- **No open questions in the final plan.** Resolve decisions before finalising.

## The two traps of vertical slicing (read first)

1. **The keystone trap.** Many refactors have a structural piece that the end-state depends on (a
   shared aggregator, a new schema, a router, a single source of truth). If you slice naively "one
   feature per slice", each slice rebuilds or duplicates that keystone — and you often *reintroduce
   the very problem the work exists to fix* (e.g. collapsing N requests into one, then slicing
   per-dimension and shipping N endpoints again). **Mitigation:** make the keystone a thin **Slice 0
   (spine)** — the minimum skeleton of the shared piece plus the simplest real increment riding on
   it — then have every later slice *extend* the spine (add one field/case/route) rather than
   re-create it. The spine only ever grows; the metric you care about only ever improves.

2. **The fake-slice trap.** A slice that only touches one layer ("just the backend endpoint") is a
   horizontal phase wearing a slice costume. A real slice goes from the data source to something the
   user or a test can observe. If a slice has no end-to-end acceptance signal, re-cut it.

## Process

### Step 1 — Context & analysis
1. Read every file/doc the user references **fully** (no limit/offset), in the main context.
   - A common entry point is an existing horizontal plan or a research doc to be re-cut into slices.
2. Spawn parallel read-only research agents (codebase-locator / codebase-analyzer /
   codebase-pattern-finder) to map the layers each increment touches and find the keystone.
3. Read the key files the agents surface. Confirm the true end-state and the shared/keystone piece.

### Step 2 — Identify the keystone & the slicing axis
- Name the **end-state invariant** (the thing that must be true when done — "one request per month",
  "all writes go through the new store", "single auth path").
- Identify the **keystone** that invariant depends on. That becomes **Slice 0 (spine)**.
- Choose the **slicing axis** for the remaining increments — usually the natural dimensions of the
  domain (one data dimension, one entity type, one user-visible feature, one route). Prefer the axis
  along which prior fragile work / bugs cluster, so each slice can re-deliver and verify one of them.
- Present the proposed **spine + slice list** to the user (titles + one line each) and get buy-in
  before writing details. Explicitly call out the keystone reasoning.

### Step 3 — Write the plan
Write to `.claude/plans/YYYY-MM-DD_HH-MM-SS_<name>.md`, following the structure in
`references/vertical-plan-template.md`. Derive metadata with `date`/`git` (or a
`scripts/spec_metadata.sh` if a sibling skill bundles one). Never leave placeholder values.

Required sections (see the template for the full skeleton):
- **Frontmatter** (title, date, git_commit, branch, repository, `structure: vertical-slices`, links,
  tags).
- **Overview** — what's being built and that it's organised as vertical slices.
- **Decisions** — resolved architectural choices (no open questions).
- **Why vertical (and the keystone caveat)** — state the end-state invariant, the keystone, and the
  spine-first reconciliation in plain terms. This is the section that stops a future implementer
  from slicing naively.
- **Current State** — verified, with `file:line`.
- **Desired End State** — the measurable invariant(s).
- **What we are NOT doing.**
- **Carry-over** (if re-cutting existing work) — a matrix mapping prior changes/fixes to the slice
  that re-delivers each, with verdict (survives / re-home / re-implement / obsolete). Nothing gets
  silently dropped.
  - **Base provenance (verify before trusting the matrix).** For each prior change, confirm whether
    it is *actually in this plan's base branch*. If it lives in an unmerged or parallel PR, decide
    and record the **donor strategy** per source: *merge-first*, *rebase-onto*, *cherry-pick*, or
    *won't-merge → take-what's-useful*. A carry-over whose source is **not** in the base will be
    silently re-implemented (duplication) or collide at merge — this is a recurring, expensive miss.
    When re-delivering, fix the **original problem** each change solved in the new architecture;
    don't port the workaround if the slice's new design removes its root cause (e.g. a client-side
    parser becomes obsolete once the backend guarantees a clean shape).
- **Slice 0 — Spine / keystone**, then **Slice 1..N** (one increment each), then any independent
  slices (e.g. correctness) that can interleave.
- **Sequencing & Dependencies** — which slices depend on the spine, and any inter-slice ordering
  (be honest about the few real dependencies; most slices should be parallelisable after Slice 0).
- **Cross-repo coordination** (if multi-repo) — contract/SDK flow per slice.
- **Testing Strategy** — per-slice acceptance signal first.

### Slice template (use for every slice)
```markdown
## Slice N — <one increment, named by what it delivers>

**Goal:** <the single observable thing this slice ships>

### Changes
- **<layer/repo>**: <concrete change, file:line>
- **<layer/repo>**: <concrete change, file:line>
  (a real slice lists changes in MORE THAN ONE layer; if it's one layer, re-cut it)

### Carry-over delivered (if any)
- #<n> <prior fix this slice re-homes/finishes>

### Dependencies
- <spine + any specific earlier slice; "none after Slice 0" is the default and the goal>

### Success Criteria
#### Verifiable now (no external dependency)
- [ ] <signal a developer can check immediately on this branch>
#### Gated on <named deploy / SDK RC / contract>
- [ ] <end-to-end signal that only works once the dependency lands — name the blocker explicitly>
```
Be honest: a slice gated end-to-end is still a valid slice, but say *what* it's gated on. Don't
label gated work as independently verifiable. When the **contract exists but the typed client or
deploy lags**, ship a **marked temporary shim** (e.g. an untyped string literal where the SDK enum
member isn't generated yet, with a `// TODO/ponytail:` marker) so the slice lands now, and **batch
the real integration once at the end** (e.g. a single SDK regen) rather than regenerating per slice.

### Step 4 — Review
Present the plan location and ask the user to check: are the slices truly independent and
end-to-end? Is the spine minimal? Are acceptance signals measurable? Iterate until satisfied.

## Quality bar (self-check before finalising)
- [ ] Slice 0 is the minimal keystone + one real increment — not a "do all the infra" phase.
- [ ] Every other slice **extends** the spine; none rebuilds or forks it.
- [ ] Every slice touches >1 layer and has an end-to-end acceptance signal.
- [ ] Most slices depend only on Slice 0 (few genuine inter-slice deps; each one stated).
- [ ] The end-state invariant is named and measurable, and at least one slice asserts it.
- [ ] Every carry-over's source is confirmed in the base branch, or a donor strategy is recorded.
- [ ] Each slice's acceptance signal is split into "verifiable now" vs "gated on <X>"; no gated
      work is mislabelled as independently verifiable.
- [ ] No open questions; all `file:line` references verified against the codebase.
