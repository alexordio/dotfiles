---
name: hub-pending
description: File what a session leaves undone as a task in agent-hub, so it is not lost in scrollback — a check that could not run, a step that waits for a merge or deploy, test data left in staging, a decision still open. Use at the end of any task that leaves something pending, and when asked "ponlo como to do", "apúntalo en el hub", "que no se nos olvide", "add it to the hub".
---

# File pending work in agent-hub

agent-hub runs on the always-on Mac mini (`alexordio/agent-hub`). Its "What's mine" list is the one list of what
needs Alexander. Write to it only through its API — never into its database:

```bash
HUB=http://100.90.69.48:8770
T=$(security find-generic-password -s agent-hub -a token -w)   # never print it
api() { curl -sf -m 10 -H "Authorization: Bearer $T" -H "Content-Type: application/json" "$@"; }
```

The mini is reached over Tailscale. If `api "$HUB/health"` fails, say so and give the user the task text to
capture by hand (⌥Space): never fall back to the old Payroll Hub (`payroll-cockpit`), which no longer takes to-dos.

## When

Before the closing summary of a task, ask: does anything here still need doing by somebody later? Typical cases:

- a verification that could not run here (needs the merge, a deploy, staging data, a login);
- a follow-up that waits on another PR, repo or person;
- test data left changed in staging or a shared environment;
- a decision the user deferred.

If yes, file it without asking — it is a private note — and say so in one line in the summary. Nothing pending:
file nothing.

## How

1. **Look for an open task first**, so the same pending is not filed twice:

   ```bash
   api "$HUB/api/items?kind=task" > /tmp/agent-hub-open.json
   ```

   Items are `{"items": [{"id", "title", "due", "source", "note", …}]}`. An open task with the same PR or topic
   → change it instead: `api -X PATCH "$HUB/api/items/<id>" -d '{"due": "YYYY-MM-DD", "title": "…", "by": "claude"}'`.

2. **Create it**, in English (it persists). Build the JSON with Python or `jq`, so quotes in the text are escaped:

   ```bash
   python3 -c 'import json, sys; print(json.dumps({"kind": "task", "by": "claude",
       "title": sys.argv[1], "due": sys.argv[2], "source": sys.argv[3], "note": sys.argv[4]}))' \
     "<repo>#<n>: <what to do, as an action>" YYYY-MM-DD "<repo>#<n>" "<see below>" \
   | api -X POST "$HUB/api/items" --data-binary @-
   ```

   `source` is the PR or issue as `repo#number` (the panel links it to GitHub), or omitted. The note is what the
   person picking it up tomorrow needs, without this conversation:
   - the exact steps, with where (URL, company, period, ids);
   - why it was not done now (the blocker, with the evidence: the error, the status code);
   - what is already verified, so it is not redone;
   - anything left behind (test values changed, slots occupied) and what it was before.

   No personal data beyond what the steps need; never secrets or tokens.

3. Tell the user in one line: the title and the due date. It is in "What's mine" at once.

## Due date

The day the blocker should be gone (tomorrow, the day after the merge), or the date the user named. No guess →
tomorrow. A task without a date sits under "No date", where it is easy to forget: give one.
