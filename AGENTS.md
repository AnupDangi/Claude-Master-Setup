# Agent Master Setup

## Mission

Ship Agent Master v1.1: a dependency-free project control plane for durable
state, evidence-based validation, and handoffs across coding agents.

## Source Map

- `lib/agent-master.js` - universal state and command implementation
- `bin/cli.js` - universal CLI plus legacy Claude installer compatibility
- `adapters/` - thin provider manifests and native integrations
- `.claude/` - optional Claude Code commands, hooks, and status line
- `templates/` - project adapters and durable documentation outlines
- `scripts/` - verification, legacy migration helpers, and release tooling

## Working Rules

- The core owns `.master/project.json`, runs, events, evidence, and claims.
- Provider adapters call the core; they do not maintain parallel task state.
- Keep schema v1 projects migratable and schema v2 state backward-readable.
- Treat `.master/runs/`, `.master/events/`, `.master/evidence/`,
  `.master/locks/`, and `.master/active-run` as ignored runtime data.
- Do not add a hosted service, daemon, distributed scheduler, or mandatory
  validator agent.
- Do not publish, commit, push, or rename the remote unless explicitly asked.

## Verify

- `npm test`
- `bash scripts/self-check.sh`
- `npm run docs:diagrams`
- `npm pack --dry-run`
- `npm pack ./compat/claude-master-setup --dry-run`

For work in this repository, use `node bin/cli.js` for the shared Agent Master
workflow and keep meaningful durable decisions in the relevant project docs.
