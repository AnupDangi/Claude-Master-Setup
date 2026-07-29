# Agent Master Protocol

`.master/` is the agent-neutral source of truth for portable task state. Claude Code, Codex, Cursor, and other agents use their own native memory and orchestration while exchanging work through this contract.

## Read Order

1. Read the tool's thin adapter: `AGENTS.md`, `CLAUDE.md`, or Cursor rules.
2. Read `.master/project.json`.
3. Run `agent-master status --format json`.
4. Verify recorded repository state with git.
5. Read only relevant `.master/docs/*` files.

## Ownership

- `project.json` stores stable project commands and sources of truth.
- `runs/<run-id>.json` stores task state, decisions, validation, blockers, and next action.
- `events/events.jsonl` stores append-only run history.
- `evidence/<run-id>/` stores validation output.
- `locks/` and ownership leases prevent conflicting writes.
- `active-run` selects the default run; `--run` selects another.

Runtime state is repository-local and gitignored. Stable project context and adapters are committed.

## Required Workflow

Start with `agent-master start "<goal>"`. Checkpoint important decisions and progress. Run `agent-master validate` before `agent-master complete`. Completion fails when validation is missing, red, or stale.

Repository evidence always overrides recorded state. Native agent memory must not replace this portable record.
