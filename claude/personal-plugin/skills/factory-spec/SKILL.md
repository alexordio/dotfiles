---
name: factory-spec
description: Prepare a change for agent-hub's software factory in this session — investigate it, settle every question with Alexander, write the spec and send it, so the factory builds it alone and he only reviews the result. Use when he says "mándalo a la factoría", "prepáralo para la factoría", "spec para la factoría", "que lo haga la factoría", or points at an issue or Slack thread for the factory.
---

# A spec for the factory, written here

The factory (agent-hub on the Mac mini + central-reviewer's engine) builds a change from an approved spec, checks
it, and stops only when it is ready to publish. Alexander touches a change **twice**: here, when he says "send
it", and on the factory's final result (Publish / Tell it something). Everything that would otherwise reach him
mid-build is settled in this session (agent-hub plan `2026-11-13_14-00-00_specs-from-the-macbook.md`, engine
decision 0043).

Talk to him in plain Spanish, one question at a time, recommendation first. The spec and the issue are English.

```bash
HUB=http://100.90.69.48:8770
T=$(security find-generic-password -s agent-hub -a token -w)   # never print it
api() { curl -sf -m 30 -H "Authorization: Bearer $T" -H "Content-Type: application/json" "$@"; }
```

If `api "$HUB/health"` fails, say the mini is not answering and stop: nothing to send to.

## 1. Where it starts

- **An issue exists** → use it.
- **Only a Slack thread** → the issue is created at the end (step 5), never at the start.
- **Found during other work** → one issue in the same epic, at the end.
- **A big feature** → do not spec it whole: discuss with him how to split it, one issue per piece, then run this
  skill per piece.

Today the factory takes only Payroll Plus issues (the Web Devs project) in the repos it works in; anything else →
say so and stop.

## 2. Does it go to the factory at all?

It does **not** when any of these holds; say which, and suggest a normal session instead:

1. it changes or cleans up existing production data (data migration, recalculation, backfill);
2. it must match a prototype or design;
3. it does not fit one reviewable PR (~400 lines per repo) → split it into issues;
4. the cause is still unknown → investigate first.

Multi-repo is fine.

## 3. Investigate before asking

Do it, then tell him in three or four lines what you found:

- read the issue or the thread **whole**: later replies, images, linked PRs;
- search open and closed issues and PRs that overlap (`gh search issues`, `gh search prs` in `ordio`): no
  duplicate work;
- look at how the sibling repos already do the same thing (payroll-api, ordio, web, payroll-frontend);
- pick a staging company or employee to verify it on (skill `ordio-staging-data`); for a bug, confirm it on real
  data (`ordio-staging-data` or `ordio-prod-data`, read only);
- for a CI or flaky-test issue, read the failing runs (`gh run view <id> --log-failed`, artifacts): the factory
  cannot.

## 4. Ask, one at a time

Only what you could not settle by looking. Each question: what is at stake in one sentence, two to four lettered
options, the recommended one first and why. Typical:

- **the payroll rule** (Lohnart, ELStAM, what is released when…): if he does not know it either, draft a short
  German question for the person who owns it (he sends it). The issue is created now with the label
  `waiting-for-rule`, and the spec is **not** sent until the answer arrives. The factory never builds on a guessed
  rule. File the wait with `hub-pending`.
- the gate: none, or which flag;
- where it shows: which app and screen;
- scope: Payroll Plus customers only or everyone.

## 5. Write the spec and the issue

The spec is `spec.SCHEMA` of the engine (`payroll-cockpit/engine/src/central_reviewer/spec.py`), JSON:

```json
{"summary": "what changes for whom, one plain sentence",
 "criteria": [{"id": "AC-1", "given": "the state", "when": "the action", "then": "the observable result"}],
 "non_goals": ["what someone might expect but this does not do"],
 "likely_files": ["payroll-api src/…"],
 "assumptions": ["everything decided without asking, each with its reason"],
 "questions": [{"id": "Q-1", "category": "business_rule", "text": "…", "options": ["…", "…"]}],
 "brain_records": []}
```

- Criteria: as few as cover it, each **testable by the repo's own tests on a local checkout**. Never one that only
  CI, a deploy or production can show: it can never pass in the factory (that stalled change 8).
- Every question he answered here goes in `questions` with its answer in `answers` (`{"Q-1": "…"}`): the
  builder sees both.
- Read `api "$HUB/api/brain/index"` and list the Brain records the spec relies on.

Show him the spec in Spanish (what it does, the criteria in one line each, what it does not do), then the issue as
it will be created or updated: title, body with problem, criteria, out of scope, how to verify (staging target and
steps), related issues and PRs, epic. Nothing is created until he says yes.

## 6. Send it

On his yes:

1. create the issue (`gh issue create`), or update the existing one;
2. put the label on: `api -X POST "$HUB/api/issues/label" -d '{"repo": "ordio/<repo>", "number": N}'`;
3. send it (build the JSON with Python so quotes are escaped):

   ```bash
   python3 -c 'import json, sys; print(json.dumps({"repo": sys.argv[1], "number": int(sys.argv[2]),
       "spec": json.load(open(sys.argv[3])), "answers": json.load(open(sys.argv[4]))}))' \
     ordio/<repo> N spec.json answers.json | api -X POST "$HUB/api/issues/study" --data-binary @-
   ```

   The answer is the task: keep its `id`.

4. The engine's critic checks the spec, a few minutes. Poll `api "$HUB/api/items/<id>/change"` every minute until
   the latest spec has `done_at`:
   - a round 1 exists → it is building. Tell him in one line; you are done.
   - the critic found gaps → explain each in Spanish, decide with him, fix the spec and approve it:
     `api -X POST "$HUB/api/items/<id>/spec-approve" -d '{"spec": {…}, "answers": {…}}'`.
   - the critic failed (`critic.error`) → tell him; he can approve it as is with the same call.

## Never

- start the build without his yes in this session;
- send a spec with an unanswered question or a guessed payroll rule;
- write to agent-hub's database or the engine directly: only the hub's API.
