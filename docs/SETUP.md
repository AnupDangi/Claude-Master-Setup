# Setup & Usage

Everything you need to go from a fresh install to a running build loop.

## Prerequisites

- **Claude Code** — install: `npm install -g @anthropic-ai/claude-code` or `brew install --cask claude-code`
- **Node.js ≥ 18** (for `npx claude-master-setup` and many MCP servers)
- **git**

No plugin marketplace required, no signup, no config wizard.

## Install (one command)

```bash
npx claude-master-setup
```

From inside your project directory. Installs the shared framework once at `~/.claude/claude-master-setup/` (idempotent — safe to re-run for any future project) and seeds **this** project's `.master/` + `CLAUDE.md`.

**Config dir resolution** (in order):
1. `--config-dir <path>` — explicit flag
2. `CLAUDE_CONFIG_DIR` — environment variable
3. `~/.claude` — default

```bash
# Framework only (no project seed)
npx claude-master-setup --framework-only

# Aliases
npx claude-master-setup --global    # alias for --framework-only
npx claude-master-setup --local     # alias for default (framework + seed)

# Custom config dir
npx claude-master-setup --config-dir /path/to/config
# or:
CLAUDE_CONFIG_DIR=/path/to/config npx claude-master-setup
```

After install, confirm the shared framework landed:

```bash
ls "$HOME/.claude/claude-master-setup/scripts/validate.sh"
ls "$HOME/.claude/agents" | head
```

## What lands where

| Location | What | Committed? |
|---|---|---|
| `~/.claude/agents/` | 11 specialist subagents | n/a (shared) |
| `~/.claude/commands/` | 11 slash commands | n/a (shared) |
| `~/.claude/claude-master-setup/` | Scripts, hooks, docs, templates | n/a (shared) |
| `~/.claude/settings.json` | Hooks, `HARNESS_FRAMEWORK_ROOT`, companion flags | n/a (shared) |
| `CLAUDE.md` | Permanent harness memory for this project | ✓ commit |
| `.master/docs/` | Starter project docs (PROJECT_STATE, ROADMAP, …) | ✓ commit |
| `.master/state/` | Loop state, leases, event log | gitignored |

The framework never lands inside your project (Decision 007). No `.github/`,
`.env`, or harness-author files are copied into your app.

## Plugin install (namespaced `/master:*` commands)

Prefer namespaced `/master:*` commands? Install as a Claude Code plugin instead:

```bash
claude plugin marketplace add AnupDangi/Claude-Master-Setup
claude plugin install master@claude-master-setup
```

Every command becomes `/master:loop`, `/master:bootstrap`, `/master:pause`, etc.
The 11 subagents, `capability-orchestrator` skill, and 5 safety hooks install automatically — nothing to copy.

**First command in a project:**

```
/master:bootstrap   # scaffolds .master/ + CLAUDE.md if needed, then foundation
/master:loop        # build loop
```

> **Mutually exclusive with npm install:** don't run both on one machine — hooks fire twice (Decision 007). Pick one path per machine.

**Local testing note:** `claude plugin marketplace add <local-path>` copies your literal working tree. A real install via `claude plugin marketplace add AnupDangi/Claude-Master-Setup` clones from GitHub — prefer the GitHub form beyond local smoke-testing.

## Five-minute tour

```
/bootstrap     # scaffolds .master if needed + foundation from PRD/PTR (no feature code)
/loop          # plan → approve → build → validate → review → approve → commit
/status        # phase, task, what the agent is doing
/pause         # stop mid-work when confused or interrupted
/decide        # supersede an architecture Decision (do not rewrite history)
/handoff       # write HANDOFF.md + sync state before ending a session
```

### Greenfield setup

Drop your requirements in the project root:

```
my-project/
├── PRD.md   # Product Requirements Document (problem, users, must-have)
└── PTR.md   # Project Technical Requirements (stack, constraints)
```

Then run `/bootstrap` (or `/master:bootstrap`). The `architect` reviews both files, asks clarifying questions, and generates `CLAUDE.md`'s project sections, `.master/docs/ARCHITECTURE.md`, `.master/docs/CODING_STANDARDS.md`, `.master/docs/TESTING.md`, and `.master/docs/ROADMAP.md`. **No feature code is written yet.** Read what it wrote before continuing.

### Brownfield setup

Existing repo without PRD/PTR? See [`BROWNFIELD.md`](BROWNFIELD.md) — `/bootstrap` inventories the tree and drafts requirements from reality.

## Build: one loop iteration

```
/loop
```

The orchestrator:
1. **SELECT** — picks the next unblocked task from `.master/docs/ROADMAP.md`
2. **DISCOVER** — finds local Claude Code skills automatically (`list-local-skills.sh`)
3. **PLAN** — generates a step plan; you approve or correct it (GATE 1)
4. **BUILD** — `implementer` writes code + tests (optional ≤5 worktree fan-out if approved)
5. **VALIDATE** — `validator` runs `scripts/validate.sh`; RED blocks (hard gate)
6. **REVIEW + SECURITY** — quality and OWASP pass; Critical/High loop back to BUILD
7. **GATE 2** — you approve the diff/commit
8. **COMMIT** — one atomic commit; `docs-writer` updates `.master/docs/`

Stop any time; resume with `/loop` — `.master/state/loop.json` remembers the phase.

**After an interrupt:** run `/status` to see the current phase, then `/loop` to continue.

## Local skills — auto-discovered on every `/loop`

The DISCOVER phase runs `list-local-skills.sh`, which indexes `SKILL.md` files from:
1. Project `.claude/skills/` (highest priority)
2. User `~/.claude/skills/`
3. Plugin caches under `~/.claude/plugins/`

Top ≤3 relevant skills are injected into each Task prompt. No web search, no marketplace — local filesystem only. Install companion skill packs (e.g. [Antigravity Skills](https://github.com/sickn33/antigravity-awesome-skills)) and they're automatically discovered.

## Worked example: first feature end-to-end

**1. Write `PRD.md` / `PTR.md`** — a few paragraphs each.

**2. `/bootstrap`** — `architect` generates `.master/docs/ROADMAP.md`:

```
## Milestone 1 — Core counting
- [ ] Parse CLI args, read file, print word/line/char counts
- [ ] Handle missing file: exit 1, clear stderr message
```

**3. `/loop`** — one iteration, concretely:

- **SELECT** — picks "Parse CLI args…", states why
- **PLAN** — classifies as `small`; you get a plan with files + tests + DoD
- **GATE 1** — you type "approve" (or correct it)
- **BUILD** — `implementer` (Sonnet) writes the files + tests
- **VALIDATE** — `validator` runs pytest; GREEN
- **REVIEW** — severity-ranked findings
- **GATE 2** — you approve
- **COMMIT** — `feat: add wordcount CLI`; `docs-writer` updates `.master/docs/PROJECT_STATE.md` and `.master/docs/CHANGELOG.md`
- **LOOP** — back to SELECT, picks next task

**4. Repeat** until roadmap has no unblocked items. Run `/evaluate` any time for an objective scorecard.

## Command reference

Bare names when installed via npm; prefixed with `/master:` when using the plugin.

| Command | What it does |
|---|---|
| `/bootstrap` | Scaffold `.master` if needed + foundation from PRD/PTR (no code) |
| `/loop` | Run/resume the build loop |
| `/status` | Phase, task, pause/clarify state |
| `/pause` | Stop mid-work; persist why |
| `/decide` | Supersede an architecture Decision |
| `/handoff` | Write HANDOFF.md + sync state before ending session |
| `/plan [task]` | Plan only (power) |
| `/validate` | Validation gate alone (power) |
| `/review [paths]` | Review alone (power) |
| `/mcp-add <tool>` | Add MCP with consent (power) |
| `/evaluate` | Optional scorecard (advanced) |

## Scripts

Live once in `~/.claude/claude-master-setup/scripts/` (or `${CLAUDE_PLUGIN_ROOT}/scripts/` for the plugin path), never copied into a project.

| Script | Purpose |
|---|---|
| `install.sh` | Harness-**development** setup only (contributor, git-clone path) |
| `validate.sh` | The hard gate: format, lint, typecheck, test, build (auto-detected per stack) |
| `detect-stack.sh` | Stack/package-manager detection (sourced by validate) |
| `self-check.sh` | Verify harness source repo's own files are wired correctly |
| `mcp-catalog.json` | Curated tool → MCP-server map |
| `list-local-skills.sh` | Index local Claude Code skills (project/user/plugin) |
| `select-skills.sh` | Token-rank skills index and return top ≤3 for a task |

### Configuring the gate for your stack

`validate.sh` auto-detects Node (npm/pnpm/yarn), Python (pip/poetry/uv), Rust, Go, and Makefile projects in the **current project** (resolved via `$CLAUDE_PROJECT_DIR`). Missing steps are skipped; a step that exists and fails makes the gate RED. Customize via your own `package.json`/`Makefile`/etc. — `validate.sh` itself lives in the shared framework, not your project. For a docs-only repo, set `HARNESS_ALLOW_NO_STACK=1`.

## Statusline (user-level only)

The status bar lives at `~/.claude/statusline.sh`, wired in `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "python3 \"$HOME/.claude/statusline.sh\""
}
```

Always points at `$HOME/.claude/statusline.sh` — never at a project path. `npx claude-master-setup` syncs and wires it automatically.

## Installation scope

| Path | When | What |
|---|---|---|
| `npx claude-master-setup` (default) | New project | Shared framework + seed this project |
| `npx claude-master-setup --framework-only` | First machine setup or framework refresh | Shared framework only |
| Plugin install | Prefer namespaced commands | Same shared-framework model, `/master:*` prefix |
| Session-only (no install) | Trying it out | `claude --settings .claude/settings.json` from a clone |

## Uninstall

```bash
# Remove shared framework
rm -rf ~/.claude/claude-master-setup ~/.claude/agents ~/.claude/commands

# Remove harness entries from ~/.claude/settings.json:
#   hooks keys: harness:session-start, harness:pre-bash-guard, harness:protect-paths,
#               harness:post-edit-track, harness:stop-validate-reminder
#   env.HARNESS_FRAMEWORK_ROOT

# Remove project footprint
rm -rf CLAUDE.md .master/
```

## Troubleshooting

- **Hooks not running?** Confirm they're wired in `~/.claude/settings.json`'s `hooks` block (npm path) or `.claude-plugin/plugin.json` (plugin path), and that you started `claude` from inside your project so `$CLAUDE_PROJECT_DIR` resolves correctly.

- **`validate.sh`/`self-check.sh` not found?** They live in the shared framework (`~/.claude/claude-master-setup/scripts/` or `${CLAUDE_PLUGIN_ROOT}/scripts/` for the plugin path), not your project — agent/command prompts reference them via `$HARNESS_FRAMEWORK_ROOT`/`${CLAUDE_PLUGIN_ROOT}`, not a bare `scripts/` path.

- **`.master/` missing after install?** Run `npx claude-master-setup` from inside your project (npm path) or `/master:bootstrap` (plugin path — scaffolds automatically).

- **Wrong project name in statusline?** Confirm `statusLine` points at `$HOME/.claude/statusline.sh` (not the project tree) and restart Claude Code.

- **Gate always RED with "no-stack"?** Your stack isn't auto-detected — set `HARNESS_ALLOW_NO_STACK=1` for a docs-only repo.

- **An agent isn't triggering?** Its description may overlap another's. Make the descriptions distinct, and restart the session to reload edited agent files.

- **Both npm-installed AND plugin-installed on one machine?** Hooks fire twice — pick one install path per machine (Decision 007).

- **MCP server won't connect?** Validate `.mcp.json` (`python3 -m json.tool .mcp.json`), confirm the env vars are set, and restart Claude Code.

- **Loop interrupted mid-task?** Run `/status` to see the current phase, then `/loop` to continue — `.master/state/loop.json` remembers exactly where it stopped.

- **Gate stuck on RED after 3 retries?** The loop enters `await-human-on-red` — investigate the root cause manually (or with `/review`), fix it, then resume `/loop`. Never loosen the check to force a pass.

## Session-level install (try before installing)

```bash
git clone https://github.com/AnupDangi/Claude-Master-Setup.git
cd Claude-Master-Setup
claude --settings .claude/settings.json
```

This loads the harness's permissions and hooks for that one session only — nothing installed anywhere. Good for evaluating before committing. See [`OPERATIONS.md`](OPERATIONS.md) for the contributor/developer setup.

## Staged growth path

**Stage 1 — Solo, single stream (day one).**
`/bootstrap` → `/loop`. One task at a time, both gates on. Complete workflow.

**Stage 2 — Add external tools.**
When a task needs a DB, GitHub, or a browser: `/mcp-add`. Keep it to what the task needs.

**Stage 3 — Parallel work with worktrees.**
For independent features, use git worktrees — each shares `CLAUDE.md` and `.master/docs/` but has its own auto-memory. See [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md).

**Stage 4 — Loosen autonomy where it's earned.**
In a well-scoped, trusted project, let the orchestrator auto-approve GATE 1 for low-risk tasks. The validation gate stays mandatory; GATE 2 stays manual for anything touching security or data.

**Stage 5 — Bundle & share.**
Extend or fork this harness and package your fork as a Claude Code plugin (Decision 005) so other repos install it in one step.
