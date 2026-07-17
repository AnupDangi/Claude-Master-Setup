# Contributing

> For humans and Claude sessions working in this repo.

## Golden rule
The **repository**, not the conversation, is the source of truth. Anything durable
goes in `docs/` or `CLAUDE.md`.

## Workflow
1. Read `CLAUDE.md`, `docs/PROJECT_STATE.md`, `docs/DECISIONS.md`.
2. Work through the loop (`/loop`) — one shippable unit, both gates, GREEN validation.
3. Update docs in the same iteration as the code.
4. `/handoff` before ending a session.

## Adding to the harness
- New agent → `.claude/agents/`; new command → `.claude/commands/`; new hook →
  `.claude/hooks/` + register in `.claude/settings.json`.
- Run `bash scripts/self-check.sh` after any harness change.

## Style
Follow `docs/CODING_STANDARDS.md`. Conventional Commits. Small atomic changes.
