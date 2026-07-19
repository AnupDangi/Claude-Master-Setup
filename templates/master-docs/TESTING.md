# Testing

> "Tested" is part of the Definition of Done. The validator runs these; the reviewer
> checks coverage of behavior, not just lines. Fill in on bootstrap.

## Frameworks & layout
- Unit: _(framework, where tests live)_
- Integration: _(…)_
- E2E: _(…, e.g. via the Playwright MCP)_

## What must be tested
- Every new behavior **and its failure path**.
- Edge cases: empty/null, boundaries, concurrency, large inputs.
- Bug fixes ship with a regression test that fails before the fix.

## Running
- Full gate: `bash scripts/validate.sh` (or `/validate`).
- Focused: _(project-specific command)_

## Standards
- Tests are meaningful, not tautological.
- No flaky tests merged; quarantine and fix.
- Never weaken or delete a test to pass the gate.
