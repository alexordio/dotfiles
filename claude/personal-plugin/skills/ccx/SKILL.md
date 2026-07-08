---
name: ccx
description: Show available Claude agents and skills for the current repo
---

# Claude Context (`/ccx`)

Run this command and capture the output:

```bash
bash ~/.claude/ccx.sh
```

Then present the information as clean markdown — no ANSI codes, no raw escape sequences. Use this structure:

## {repo} · {branch}

### Agents
| Name | Description |
|------|-------------|
| `name` | description |

### Skills — global
| Command | Description |
|---------|-------------|
| `/skill` | description |

### Skills — this repo
| Command | Description |
|---------|-------------|
| `/skill` | description |

Keep descriptions to one sentence. Omit the "Skills — this repo" section if empty.
