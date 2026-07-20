# Claude Master Setup

## Mission

Ship a minimal Claude Code harness: understand each repo first, route work through
a fail-closed adaptive loop, and require binary validation before completion.

## Stack

- Node 18+ installer: `bin/cli.js`
- Commands, agents, hooks: `.claude/`
- Runtime helpers: `scripts/`
- Outlines only (never auto-copied into consumer projects): `templates/master-docs/`

## Verify

- `npm test` — self-check, allowlist, CLI syntax, ship-install, golden-loop
- `bash scripts/self-check.sh` — wiring and loop gates
- `npm pack --dry-run` — published tarball contents

## Product surface

Commands: `/bootstrap`, `/loop`, `/cancel`, `/status`, `/pause`, `/handoff`.
Defaults: `iteration_budget` from `.master/project.json` (else 2). Routing:
direct · delegated · parallel. Session memory is JSON + handoff, not chat.

## Control plane (non-negotiable)

- Delegated/parallel: no product Write/Edit until `assigned_agents` is set
- Completion needs GREEN validation, `ship_completed`, and (non-direct) validator + AGENT_TASK
- Docs are **generated from evidence** at bootstrap/SHIP — never bulk-copied from templates
- One writer per file; parallel work uses isolated worktrees (≤3)

## Conventions

- Consumer output stays project-specific and minimal
- Explicit package/installer allowlists; never ship `.env` or `.github`
- Keep JSON state backward-readable; update tests when schema changes
- Validation exit code is binary: 0 = GREEN, else RED
- No new commands/docs/agents without a runtime need
- Atomic conventional commits; never commit credentials
- Maintainer edits to control-plane: `HARNESS_ALLOW_PROTECTED_EDITS=1`
