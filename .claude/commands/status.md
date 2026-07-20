---
description: Show compact project, loop, validation, and handoff status
argument-hint: ""
allowed-tools: Read, Bash(python3:*), Bash(git branch:*), Bash(git status:*)
model: haiku
---

# Status

## Role

You report **current machine state** for humans. Prefer files over chat memory.

## Data

Read (do not dump raw JSON to the user):

- `.master/project.json`
- `.master/state/loop.json`
- `.master/state/handoff.json` (if present)

Also: `git branch --show-current` and `git status --short`.

## Output (≤8 lines)

- **Phase:** …
- **Iteration:** current/max
- **Status:** running|paused|completed|cancelled|max_iterations|idle
- **Agents:** count + names from `assigned_agents` (or none)
- **Stall / error / blocked:** values or none
- **Validation:** green|red|pending
- **Recovery:** e.g. `/loop "…"` · `/loop` steer · `/loop` after pause · `/bootstrap`

If not bootstrapped, say so in one line and stop.
