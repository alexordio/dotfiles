---
name: brain-propose
description: Put a decision Alexander just took into the Brain (alexordio/brain), the knowledge every agent in agent-hub's software factory reads. Use when, in a session, he decides or corrects how agents should work in Ordio's repos — a convention, a rule, a "never do X", a "this is how Y works" that is not obvious from the code — and when you save a feedback/project memory about Ordio work. Also when asked "al Brain", "apúntalo en el Brain", "add it to the Brain".
---

# Propose a decision to the Brain

The Brain is a repo of decision records (`decisions/NNNN-slug.md`) on the Mac mini. Every agent of the software
factory gets its index (one line per record) in its prompt. A record goes in only with Alexander's yes, asked in
this session. Write to it only through agent-hub's API:

```bash
HUB=http://100.90.69.48:8770
T=$(security find-generic-password -s agent-hub -a token -w)   # never print it
api() { curl -s --fail-with-body -m 60 -H "Authorization: Bearer $T" -H "Content-Type: application/json" "$@"; }
```

If `api "$HUB/health"` fails, say so in one line and stop: no other way in.

## When

Only a decision that changes how agents should work in Ordio's repos and that an agent could not learn from the
code, git or the repo's CLAUDE.md. Not: one-off facts of this task, personal preferences about chat, anything a
lint/test/hook could enforce (propose that check instead). If unsure, do not ask: one question too many costs more
than a missed record, which he can still add by saying "al Brain".

## How

1. **Read the index** and look for the same topic:

   ```bash
   api "$HUB/api/brain/index" | python3 -c 'import json,sys; print(json.load(sys.stdin)["index"])'
   ```

   Already there and still right → nothing to do. There but this decision changes it → propose it as superseding
   that id (open it first if needed: the record lives in `~/Desktop/Repos Ordio/brain/decisions/`, pull first).

2. **Ask in one line**, in his language, the decision and its why as they will be written:
   `¿Al Brain: <decision>, porque <why>?` (add `— sustituye 00NN` when superseding). Wait for the answer. No → drop it.

3. **On yes**, post it in English (it persists), with the wording he approved:

   ```bash
   python3 -c 'import json, sys; print(json.dumps({"title": sys.argv[1], "decision": sys.argv[2], "why": sys.argv[3],
       "source": sys.argv[4], "scope": sys.argv[5], "supersedes": sys.argv[6] or None}))' \
     "<short title, as an imperative or a fact>" "<the decision, 1–4 lines>" "<why, one line>" \
     "session: <repo> <YYYY-MM-DD>" "<repo name, or all>" "<id or empty>" \
   | api -X POST "$HUB/api/brain/records" --data-binary @-
   ```

   201 → `{"id", "path", "commit"}`: it is committed and pushed, and the next agent sees it. Tell him in one line:
   `Brain 00NN: <title>`. 400 says why (a record with that title exists: supersede it). 502: the mini could not
   write or push; say so with the error.
