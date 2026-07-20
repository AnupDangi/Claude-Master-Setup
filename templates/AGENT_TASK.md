# Agent task template

Every Task spawned during `/loop` MUST follow this structure.

## Objective

One sentence: the bounded slice to complete this phase.

## Context

- Loop prompt and current `phase` from `.master/state/loop.json`
- Relevant paths from `CLAUDE.md` and `.master/project.json`
- `owned_files` when provided (do not edit outside them)

## Inputs

- Files to read first (max 5 paths)
- Selected skills (max 3 paths — read before work)

## Constraints

- Match existing code style and conventions
- No unrelated docs, no harness edits, no secrets in output
- Anti-stall: never background `npm/pnpm/yarn/pip/cargo` installs; use foreground with timeout
- If blocked >60s or command fails twice, stop and report blocker (do not spin)

## Expected output

- Files changed (list)
- Tests or checks run (commands + result)
- Blockers (if any)
- For planner/architect: decision or task graph only — **no code**

## Validation requirements

- implementer: run focused tests for touched code
- validator: run full `validate.sh`; report GATE GREEN or RED with stage/errors
- reviewer: severity-ranked findings on current diff only

## Do not

- Spawn subagents (nested Task) unless you are orchestrator dispatching implementers
- Weaken validation or skip failing checks
- Invent architecture not grounded in the repo
- Claim GREEN without running the configured validation command
