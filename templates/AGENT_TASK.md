# Agent task template

Every Task spawned during `/loop` MUST use this structure. Fill every section.
Chat is not memory — this file plus `loop.json` define the slice.

## Objective

One sentence: the bounded slice to complete this phase.

## Context

- Loop prompt:
- Current `phase` (from `.master/state/loop.json`):
- Relevant project facts (from `CLAUDE.md` / `project.json`):
- `owned_files` (do not edit outside these when non-empty):

## Inputs

- Files to read first (max 5 paths):
- Selected skills (max 3 paths — read before work):

## Constraints

- Match existing code style and conventions
- No unrelated docs, no harness edits, no secrets in output
- No nested Task unless you are orchestrator dispatching implementers

### Anti-stall

- Never background `npm` / `pnpm` / `yarn` / `pip` / `cargo` installs — foreground with timeout
- Same command fails twice with the same error → stop and report blocker
- Blocked >60s on a process → kill and report
- Never invent architecture not grounded in the repo
- Never claim validation GREEN without running the configured command

## Expected output

- Files changed (list)
- Tests or checks run (commands + result)
- Blockers (if any)
- planner/architect: decision or task graph only — **no product code**

## Validation requirements

- implementer: focused tests for touched code
- validator: full validate.sh / validate_cmd; GATE GREEN or RED
- reviewer: severity-ranked findings on current diff only (read-only)

## Do not

- Weaken validation or skip failing checks
- Expand scope beyond Objective / owned_files
- Treat prior chat as authoritative over this file or `loop.json`

---

## Example (filled)

```markdown
## Objective
Add exit code 2 when hypothesis start is called without locked fields.

## Context
- Loop prompt: gate start behind locked hypothesis
- phase: build
- owned_files: [src/gate.ts, tests/gate.test.ts]

## Inputs
- Files: src/gate.ts, src/cli.ts, tests/gate.test.ts
- Skills: (none)

## Constraints
- Keep gate pure; no network
- Anti-stall rules apply

## Expected output
- Changed files + node:test results

## Validation requirements
- implementer: npm test -- tests/gate.test.ts
```
