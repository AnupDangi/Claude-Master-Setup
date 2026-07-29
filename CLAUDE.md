# Claude Code Adapter

Read `AGENTS.md` first. It is the project contract for every coding agent.

Use the shared core through:

- `/init`, `/start`, `/status`, `/checkpoint`
- `/validate`, `/handoff`, `/complete`
- `/pause`, `/cancel`

`/bootstrap` and `/loop` remain compatibility aliases. Claude-specific hooks
and agents are optional enhancements; `.master/` is the shared source of truth.
