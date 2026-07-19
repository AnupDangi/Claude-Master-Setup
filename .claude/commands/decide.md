---
description: Change or supersede an architecture decision — updates DECISIONS.md without rewriting history
argument-hint: <what to change, e.g. "switch from Postgres to SQLite">
allowed-tools: Read, Grep, Glob, Task, Write, Edit, Bash(bash */scripts/*.sh:*), Bash(bash scripts/:*)
model: opus
---

# Supersede an architecture decision

Argument: !`echo "${ARGUMENTS:-describe the change}"`

## When to use

The human wants a different stack, boundary, or policy than an existing
**Decision** in `.master/docs/DECISIONS.md`. Never silently rewrite the old entry.

## Steps

1. If `.master/state/loop.json` has `phase` in `build` / `validate` / `review`,
   pause first (set `phase` to `paused`, note reason) or tell the human to run
   `/master:pause`.
2. Read `.master/docs/DECISIONS.md` and `.master/docs/ARCHITECTURE.md`.
3. Delegate to the **architect** subagent with the proposed change.
4. Append a **new** Decision (next number) with status `accepted`. Mark the old
   Decision `superseded by Decision NNN`. Do not delete or rewrite the old body.
5. Update `.master/docs/ARCHITECTURE.md` if the change affects the design summary.
6. Update `.master/docs/PROJECT_STATE.md` with one line: decision changed + why.
7. Report: old Decision id, new Decision id, what `/master:loop` should do next
   (often re-plan the current roadmap item).

## Do Not

- Do not invent a new architecture without human confirmation of the Decision.
- Do not continue the previous BUILD plan if it assumed the old Decision —
  require a fresh `/master:plan` or `/master:loop` after approval.
