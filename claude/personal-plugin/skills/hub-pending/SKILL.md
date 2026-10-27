---
name: hub-pending
description: File what a session leaves undone as a To-do in the Payroll Hub, so it is not lost in scrollback — a check that could not run, a step that waits for a merge or deploy, test data left in staging, a decision still open. Use at the end of any task that leaves something pending, and when asked "ponlo como to do", "apúntalo en el hub", "que no se nos olvide", "add it to the hub".
---

# File pending work in the Payroll Hub

The hub is `~/payroll-hub`: one Markdown file per item, shown on the Payroll Hub board
(To do = status `accepted`). Its only writer is the cockpit's CLI — never write item files
by hand:

```bash
HUB="/Users/alexander/Desktop/Repos Ordio/payroll-cockpit/collector/hub.py"
```

Every command prints JSON and exits non-zero with the reason on stderr.

## When

Before the closing summary of a task, ask: does anything here still need doing by somebody
later? Typical cases:

- a verification that could not run here (needs the merge, a deploy, staging data, a login);
- a follow-up that waits on another PR, repo or person;
- test data left changed in staging or a shared environment;
- a decision the user deferred.

If yes, file it without asking — it is a private local note — and say so in one line in the
summary. Nothing pending: file nothing.

## How

1. **Look for an open item first**, so the same pending is not filed twice:

   ```bash
   python3 "$HUB" list > /tmp/hub-list.json
   ```

   Items are a JSON list with `id`, `status`, `title`, `source`, `due`. An item still open
   (`new`, `researching`, `ready`, `accepted`, `in_progress`, `review`) with the same PR or
   topic → update it with `python3 "$HUB" edit <id> --due … --title …` instead.

2. **Capture**, in English (it persists):

   ```bash
   python3 "$HUB" capture \
     --title "<repo>#<n>: <what to do, as an action>" \
     --due YYYY-MM-DD \
     --priority urgent|high|medium|low \
     --source "<PR / issue refs>" \
     --note "<see below>"
   ```

   The note is what the person picking it up tomorrow needs, without this conversation:
   - the exact steps, with where (URL, company, period, ids);
   - why it was not done now (the blocker, with the evidence: the error, the status code);
   - what is already verified, so it is not redone;
   - anything left behind (test values changed, slots occupied) and what it was before.

   No personal data beyond what the steps need; never secrets or tokens.

3. **Move it to To do**: `python3 "$HUB" act <id> accept`. A plain capture lands in Ideas.

4. Tell the user in one line: the title, the due date, and that it is in To do.

## Due date

The day the blocker should be gone (tomorrow, the day after the merge), or the date the user
named. No guess → tomorrow.
