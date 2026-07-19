# Claude Master Setup

## Mission

Maintain a minimal Claude Code extension that understands each repository first,
ships code through adaptive iteration, and requires real validation before completion.

## Stack

- Node.js 18+ installer: `bin/cli.js`
- Claude Code commands, agents, and hooks: `.claude/`
- Portable shell/Python runtime helpers: `scripts/`
- Project seed templates: `templates/`

## Verify

- `npm test` — self-check, JavaScript syntax, and clean-install smoke tests
- `bash scripts/self-check.sh` — repository wiring and loop behavior
- `npm pack --dry-run` — published tarball contents

## Product surface

Commands: `/bootstrap`, `/loop`, `/cancel`, `/status`, `/pause`, `/handoff`.
The loop defaults to two iterations and routes work as direct, delegated, or parallel.
Project state lives in `.master/*.json`; framework behavior stays in this package.

## Conventions

- Keep consumer project output project-specific and minimal.
- Use explicit package and installer allowlists; never ship `.env` or `.github`.
- Keep JSON state backward-readable and update tests when its schema changes.
- One writer per file; parallel writers use isolated git worktrees.
- Validation exit code is binary: zero is GREEN, anything else is RED.
- Do not add commands, docs, agents, or environment dials without a runtime need.
- Use atomic conventional commits; never commit credentials.
