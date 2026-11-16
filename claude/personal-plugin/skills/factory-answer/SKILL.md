---
name: factory-answer
description: Answer what agent-hub's software factory asks Alexander about one change — a spec to approve, a decision, a failed round, a result or review answers ready to publish — from a Claude Code session, usually the one herdr's Factory tab opened for it. Use when the prompt names a factory change ("el cambio <id> del hub", factory-answer <id>), or he says "contesta a la factoría", "qué me pide la factoría".
---

# Answer the factory about one change

The factory (agent-hub on the mini + central-reviewer's engine) stops a change only when it needs Alexander. This
session is where he answers: you read the change, explain in plain Spanish what is asked and what you recommend, and
send **only what he says yes to**, through agent-hub's API. Never write to the hub's store or the engine directly.

Call the hub only through agent-hub's helper, which takes the token from the keychain and never prints it (no
`curl`):

```bash
HUBAPI="$HOME/Desktop/Repos Ordio/agent-hub/herdr/hub_api.py"
python3 "$HUBAPI" get /api/items/<id>
python3 "$HUBAPI" post /api/items/<id>/rounds '{"comments": [{"where": "D-1", "text": "…"}]}'
```

It prints the hub's JSON and exits 1 on a refusal (the JSON says why). If it cannot reach the hub, say the mini does
not answer and stop.

## 1. Read the change

- `get /api/items/<id>` → `item.data.change.status` says what is asked (table below), plus the item's title.
- `get /api/items/<id>/change` → the whole change: `specs` (each `spec` with criteria and questions, `critic`
  gaps), `rounds` (each `result`: `explanation` in Spanish with `what_it_does`, `criteria`, `open`, `decisions`;
  `approver` with `reasons`; `pr` draft; `repos.<repo>` with `files`, `diff`, `review`, `tests`, `risk.must_view`),
  `prs`, `feedback` (review points and how the factory judged each). It is large: read it into a file and pick
  what you need with `python3`, never print it whole.

## 2. Say what is asked

In Spanish, short: what the change does (one or two lines), what the factory needs from him, and your recommendation
with its reason. Then wait. One question at a time if there are several.

| `status` | What is asked | The one call that answers it |
| --- | --- | --- |
| `spec-ready` | Approve the spec: its questions need answers; the critic's gaps, if any, need a decision | `post /api/items/<id>/spec-approve` `{"spec": <the spec, edited if he asked>, "answers": {"Q-1": "…"}}`, or `post …/spec-steer` `{"comments": [{"where": "", "text": "…"}]}` for a new version |
| `spec-failed` | The spec agent failed | `spec-steer` with a comment asking to write it again |
| `stopped` | The approver stopped the round: a product decision (`explanation.decisions`, each with options and `recommended`), or `approver.reasons` no automatic round fixed | `post …/rounds` `{"comments": [{"where": "D-1", "text": "<his choice and why>"}]}`; or publish as it is if he decides so |
| `failed` | The round failed (an engine or agent error) | `rounds` with a comment to build it again from the approved spec |
| `ready`, no `prs` | The result passed: review it and publish | `post …/publish` `{"draft": false, "link": "closes", "viewed": [<every "repo:path" in risk.must_view>]}` |
| `ready`, with `prs` | The answers to the PR's review are ready: pushing them answers each thread | the same `publish` call |

Before publishing, show him: `what_it_does`, each criterion and whether it is met, the `open` points, and the diff of
every file in `risk.must_view` (he must have seen it: only then list it in `viewed`). For review answers, show each
feedback point with the factory's verdict (fix, decline, ask) and its reply.

## 3. Send it

Only after his explicit yes in this session, the one call from the table. Show the answer of the call in one line
(the PR link on publish). A refusal (400/409) says why: explain it and ask how to go on.

## Never

- send anything he did not say yes to, or answer a question for him;
- edit the spec or a comment's text beyond what he said;
- publish without showing the must-view diffs;
- discard a change (`post …/discard`) unless he asks for exactly that.

When done, say in one line that the change goes on in the factory: the herdr tab follows it, and this pane closes by
itself once you are idle.
