# Agent Master

**v1.1.0** — Portable project state, validation evidence, and reliable handoffs across Claude Code, Codex, Cursor, and other coding agents.

<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/adfd0f0e-3e84-497e-9906-80541395f20a" />

Agent Master lets one coding agent begin a task and another continue it without shared chat history. Each agent keeps its native memory, goals, skills, plugins, approvals, and orchestration. They exchange only durable task facts through the repository-local `.master/` contract.

```bash
npx agent-master-setup@latest init
agent-master start "add secure refresh-token rotation" --agent codex
```

## Why Agent Master

| Agent-owned | Agent Master-owned |
|---|---|
| Native memory and conversation history | Portable task objective and current phase |
| `/goal`, sessions, plans, and subagents | Decisions, completed work, remaining work, blockers |
| Skills, plugins, rules, hooks, and tools | Repository snapshot and file ownership |
| Provider-specific autonomous execution | Validation evidence and completion gate |

There is no second chat system and no universal agent replacement. Agent Master is a small shared control plane underneath native coding agents.

## Architecture

[![Agent Master architecture](https://raw.githubusercontent.com/AnupDangi/Claude-Master-Setup/main/docs/architecture.png)](https://github.com/AnupDangi/Claude-Master-Setup/blob/main/docs/architecture.mmd)

Editable source: [`docs/architecture.mmd`](docs/architecture.mmd). Regenerate all committed PNGs with `npm run docs:diagrams`.

## Quick Start

### Initialize a project

```bash
cd your-project
npx agent-master-setup@latest init
```

Initialization is project-local and does not require Claude, Codex, or Cursor. It creates:

```text
your-project/
├── AGENTS.md
├── CLAUDE.md
├── .cursor/rules/master-protocol.mdc
└── .master/
    ├── README.md
    ├── project.json
    ├── active-run
    ├── runs/<run-id>.json
    ├── events/events.jsonl
    ├── evidence/<run-id>/
    ├── locks/
    └── docs/
```

Stable context and adapters may be committed. Runtime state, locks, and validation logs are gitignored so command output and transient task details are not published accidentally.

### Start and continue work

```bash
agent-master start "add authentication" --run auth --agent claude-code
agent-master status --format json

agent-master checkpoint --run auth --agent codex \
  --completed "Implemented token rotation" \
  --decision "Store only hashed refresh tokens" \
  --remaining "Add replay protection test" \
  --next "Run the authentication integration suite"

agent-master handoff --run auth --agent codex \
  --next "Verify replay protection, then validate"
```

The next agent runs `agent-master status --format json`, verifies the recorded branch, commit, changed files, and working tree with git, then continues from `next_action`. Repository evidence always wins over stale recorded state.

## Universal Commands

```text
agent-master init
agent-master start "<goal>" [--run ID] [--agent NAME]
agent-master status [--run ID] [--format json]
agent-master inspect [--run ID] [--format json]
agent-master checkpoint [progress flags]
agent-master validate [--run ID]
agent-master handoff [--run ID] [--next TEXT]
agent-master complete [--run ID]
agent-master pause [--run ID] [--blocker TEXT]
agent-master cancel [--run ID] [--reason TEXT]
agent-master claim [--run ID] <files...>
agent-master release [--run ID] <files...>
agent-master doctor
agent-master pack list|add|remove [name]
```

These commands contain the state transitions. Provider prompts and rules are thin wrappers.

## Validation Evidence

Configure checks in `.master/project.json`:

```json
{
  "schema_version": 2,
  "project_id": "checkout",
  "maturity": "production",
  "install_command": "npm install",
  "test_commands": [
    "npm test",
    "npm run typecheck"
  ],
  "build_command": "npm run build",
  "runtime_check": null,
  "sources_of_truth": [
    "src",
    "tests",
    "README.md"
  ]
}
```

`agent-master validate` runs every configured check and stores command, exit code, timestamps, and an output reference under `.master/evidence/<run-id>/`.

GREEN evidence automatically becomes stale when:

- HEAD changes.
- The tracked or untracked working tree changes.
- Required validation commands change.
- A configured runtime check was not executed successfully.

`agent-master complete` rejects missing, RED, or stale evidence.

## Multiple Runs and File Claims

```bash
agent-master start "add authentication" --run auth
agent-master start "improve checkout UI" --run checkout-ui

agent-master claim --run auth src/auth/session.ts src/auth/refresh.ts
agent-master claim --run checkout-ui src/checkout/summary.tsx
```

Claims use repository-local leases. An active run cannot claim a file owned by another live run unless the operator explicitly forces the claim. Agent Master does not implement a distributed scheduler.

## Provider Adapters

| Provider | Project instructions | Native enhancement | Shared implementation |
|---|---|---|---|
| Claude Code | `CLAUDE.md` + `AGENTS.md` | Commands, optional hooks, subagents, worktrees | Agent Master CLI |
| Codex | `AGENTS.md` | `/goal`, native memory, optional `$agent-master` skill | Agent Master CLI |
| Cursor | `AGENTS.md` + project rule | Native sessions and terminal | Agent Master CLI |
| Copilot, Antigravity, Hermes | `AGENTS.md` | Their native skills and workflows | Agent Master CLI |

Capability declarations live under `adapters/<provider>/capabilities.json`. Missing native features degrade to explicit CLI actions rather than blocking the workflow.

### Claude Code

Install the optional global Claude bridge:

```bash
npx agent-master-setup@latest install claude
```

Plugin users can keep the existing marketplace key:

```bash
claude plugin marketplace add AnupDangi/Claude-Master-Setup
claude plugin install master@claude-master-setup
```

Commands include `/master:init`, `/master:start`, `/master:status`, `/master:checkpoint`, `/master:validate`, `/master:handoff`, `/master:complete`, `/master:pause`, and `/master:cancel`. `/bootstrap` and `/loop` remain compatibility aliases.

Use either the npm-installed Claude bridge or the Claude plugin, not both, so optional hooks do not run twice.

### Codex

Codex works immediately through root `AGENTS.md` and the CLI. Install the optional reusable skill globally:

```bash
npx agent-master-setup@latest install codex
```

Start a new Codex task and invoke `$agent-master` when you want the guided resume/checkpoint/validate/handoff workflow. Codex `/goal` and Codex memory remain native; they are not copied into `.master/`.

### Cursor

`agent-master init` creates an always-applied project rule. The explicit provider command is idempotent:

```bash
npx agent-master-setup@latest install cursor
```

Cursor is first-class when it can start, inspect, continue, checkpoint, validate, hand off, and complete the same portable run through its terminal.

## Existing Project Migration

`agent-master init` detects:

```text
.master/state/loop.json
.master/state/handoff.json
.master/state/history/events.jsonl
```

It migrates the task into `.master/runs/<generated-run-id>.json`, preserving the goal, status, phase, iteration, assigned agents, corrections, validation result, branch, commit, remaining work, blockers, next action, updater, and event history.

Legacy GREEN validation becomes **stale** because old state does not contain reproducible evidence. Run validation again before completion.

## npm Package Rename

The new package is `agent-master-setup`. npm package names cannot be renamed in place, so `claude-master-setup@1.0.4` is maintained as a compatibility wrapper that delegates to Agent Master v1.1.

Recommended migration:

```bash
npx agent-master-setup@latest init
```

After the compatibility release is available, the old npm package can be deprecated with a message pointing to `agent-master-setup`; it should not be unpublished.

## Optional Packs

The interface is reserved:

```bash
agent-master pack list
agent-master pack add graph-engineering
agent-master pack remove graph-engineering
```

`graph-engineering` is listed as planned and is intentionally not shipped in v1.1. Core handoff reliability does not depend on optional packs.

## Maintainer Verification

```bash
npm test
npm run docs:diagrams
npm pack --dry-run
npm pack ./compat/claude-master-setup --dry-run
```

Publishing order:

1. Publish `agent-master-setup@1.1.0`.
2. Publish `compat/claude-master-setup` as `claude-master-setup@1.0.4`.
3. Verify both package pages and commands.
4. Deprecate older `claude-master-setup` versions with the migration message.

This repository does not publish, commit, push, deprecate, or tag packages automatically.

## Scope

v1.1 does not include cloud synchronization, a hosted dashboard, autonomous background execution, automatic PR merging, production deployment, a distributed scheduler, or the full graph-engineering pack.

## License

MIT © Anup Dangi
