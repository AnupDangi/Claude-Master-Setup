# Setup

**Product version:** 1.1.0.

Agent Master has two installation scopes:

- Project scope: `.master/` plus thin agent adapters.
- Provider scope: optional native Claude, Codex, or Cursor integration.

## Project Initialization

```bash
cd your-project
npx agent-master-setup@latest init
```

No coding-agent CLI is required. Existing `AGENTS.md`, `CLAUDE.md`, Cursor rules, and `.master/README.md` are never overwritten.

Initialization creates or upgrades `.master/project.json` to schema v2 and ensures:

```text
.master/
├── README.md
├── project.json
├── active-run
├── runs/
├── events/
├── evidence/
├── locks/
└── docs/
```

Runtime entries are added to `.gitignore`. `.env`, `.env.*`, and legacy `.master/state/` remain ignored.

## Claude Code Provider

Install the shared Claude bridge:

```bash
npx agent-master-setup@latest install claude
```

This installs commands, optional safety/notification hooks, statusline support, templates, and the universal CLI under the selected Claude config directory.

Alternatively, use the existing plugin marketplace:

```bash
claude plugin marketplace add AnupDangi/Claude-Master-Setup
claude plugin install master@claude-master-setup
```

Use either the npm Claude bridge or the plugin, not both. Legacy installer flags remain available:

```bash
npx agent-master-setup --framework-only
npx agent-master-setup --repair
npx agent-master-setup --doctor
```

The `--doctor` form audits the legacy Claude provider install. `agent-master doctor` audits the universal project contract.

## Codex Provider

Codex works through root `AGENTS.md` without global changes. Install the optional skill:

```bash
npx agent-master-setup@latest install codex
```

The skill is installed under `${CODEX_HOME:-~/.codex}/skills/agent-master`. Start a new Codex task before invoking `$agent-master`.

Codex `/goal`, memories, subagents, plugins, approvals, and task state remain Codex-owned. Agent Master stores only cross-agent facts needed to continue repository work.

## Cursor Provider

Initialization creates `.cursor/rules/master-protocol.mdc`. The explicit provider command is idempotent:

```bash
npx agent-master-setup@latest install cursor
```

Cursor uses its native sessions and terminal. The rule instructs it to verify git, continue from `next_action`, checkpoint progress, and require current validation.

## Project Configuration

Example `.master/project.json`:

```json
{
  "schema_version": 2,
  "project_id": "checkout",
  "name": "checkout",
  "maturity": "production",
  "install_command": "npm install",
  "test_commands": [
    "npm test",
    "npm run typecheck"
  ],
  "build_command": "npm run build",
  "runtime_check": "curl -sf http://localhost:3000/health",
  "sources_of_truth": [
    "src",
    "tests",
    "README.md"
  ]
}
```

Initialization infers conservative commands from common Node, Python, Rust, Go, and Make project evidence. Review the file before relying on completion gates.

## Migration

Run:

```bash
agent-master init
```

Migration reads legacy loop, handoff, and JSONL history. It creates one generated run, sets it active, copies portable fields, and preserves the complete old objects under `adapter_state["claude-code"]`.

Migration is idempotent. Existing legacy files are left in place and remain gitignored.

## Package Rename

The primary package is `agent-master-setup@1.1.0`. A separately publishable compatibility package lives at `compat/claude-master-setup` and delegates `claude-master-setup@1.0.4` to the new package.

Publish the new package first:

```bash
npm test
npm pack --dry-run
npm publish
```

Then publish the compatibility wrapper:

```bash
npm pack ./compat/claude-master-setup --dry-run
npm publish ./compat/claude-master-setup
```

After verification, deprecate old versions with a migration message. Do not unpublish them.

## Update and Uninstall

Re-run `npx agent-master-setup@latest init` to upgrade a project contract. Re-run a provider install to refresh that provider bridge.

Removing a provider bridge does not require deleting `.master/`. Remove `.master/` only when portable task history and project configuration are no longer needed.
