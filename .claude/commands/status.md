---
description: Show compact project, loop, validation, and handoff status
argument-hint: ""
allowed-tools: Read, Bash(cat:*), Bash(git branch:*), Bash(git status:*)
model: haiku
---

# Status

- Project: !`cat .master/project.json 2>/dev/null || echo "not bootstrapped"`
- Loop: !`cat .master/state/loop.json 2>/dev/null || echo "no loop state"`
- Handoff: !`cat .master/state/handoff.json 2>/dev/null || echo "no handoff"`
- Branch: !`git branch --show-current 2>/dev/null || echo "not a git branch"`
- Changes: !`git status --short 2>/dev/null || echo "git status unavailable"`

Summarize the above data in human-readable form. Do NOT dump raw JSON. Instead, report these fields:
- **Phase**: current loop phase (gate/plan/build/validate/review/ship/complete)
- **Iteration**: current/max iterations
- **Status**: running/paused/completed/cancelled/max_iterations
- **Agents spawned**: count and names from assigned_agents
- **Stall count**: stall_count value
- **Last error**: last_error value (if any)
- **Blocked on**: blocked_on value (if any)
- **Validation**: green/red/pending
- **Recovery hint**: suggested next action (e.g. `/loop steer "..."` or `/loop resume`)

Keep the summary to at most eight lines. Do not read additional docs.
