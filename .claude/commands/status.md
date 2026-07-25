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
- `.master/state/history/events.jsonl` — last 10 lines (if file exists)

Prefer: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/query-events.py --last 8` when that script exists
(falls back to reading the JSONL file).

Also: `git branch --show-current` and `git status --short`.

## Output (≤14 lines)

- **Phase:** …
- **Iteration:** current/max
- **Mode:** `execution_mode` — direct|delegated|parallel|unclassified
- **Routing reason:** `routing_reason` from loop.json (or none if unclassified)
- **Status:** running|paused|completed|cancelled|max_iterations|idle
- **Agents:** count + names from `assigned_agents` (or none); if mode is delegated/parallel and `assigned_agents` is empty, say **"agents: NONE — gate will block product writes"**
- **Stall / error / blocked:** values or none
- **Validation:** green|red|pending
- **Recent events (last ≤5):** from `events.jsonl` / `query-events.py` — show `type`, short `ts`, and attempt lineage (`attempt_id` ← `parent_event`) when present; if file absent say "no events yet"
- **Worktree:** if any recent event has `worktree`, note it
- **Recovery:** e.g. `/loop "…"` · `/loop` steer · `/loop` after pause · `/bootstrap`

If not bootstrapped, say so in one line and stop.
