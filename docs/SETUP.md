# Setup & Usage

Everything you need to go from a fresh clone to a running, self-driving build loop.

## Prerequisites

- **Claude Code** — install: `curl -fsSL https://claude.ai/install.sh | bash`
- **Node.js** (for many MCP servers and JS/TS projects) — optional otherwise.
- **git**.

No plugin marketplace, no signup, no config wizard. The harness is just files in
this repo that Claude Code already knows how to read.

## Install

```bash
git clone <this-repo> my-project
cd my-project
bash scripts/install.sh      # makes scripts/hooks executable, seeds .env & state
claude                       # start Claude Code — hooks & permissions load automatically
bash scripts/self-check.sh   # verify the harness is wired correctly
```

## Bootstrap a project

Drop your requirements in the repo root:

```
my-project/
├── PRD.md   # Product Requirements Document
└── PTR.md   # Project Technical Requirements
```

Then, in Claude Code:

```
/bootstrap
```

The architect reviews the design, asks clarifying questions, and generates
`CLAUDE.md` project sections, the full `docs/` set, and `docs/ROADMAP.md` — an
ordered list of small tasks the loop can consume. **No code is written yet.** You
approve the foundation before building starts.

## Build

```
/loop
```

The orchestrator runs the loop from `docs/LOOP.md`: it picks the next task, plans it,
waits for your approval, builds it with tests, runs the validation gate (hard-blocks
on RED), reviews it, waits for your merge approval, commits, updates docs, and
repeats. Stop any time; resume with `/loop` — the repository remembers where it was.

## Command reference

| Command | What it does |
|---|---|
| `/bootstrap` | PRD + PTR → engineering foundation (no code) |
| `/loop` | Run/resume the plan→build→validate→review→commit loop |
| `/plan [task]` | Plan a task without building it |
| `/validate` | Run the validation gate now (GREEN/RED) |
| `/review [paths]` | Review the current diff (quality + security) |
| `/mcp-add <tool>` | Check for an MCP server and add it (with consent) |
| `/handoff` | Write HANDOFF.md and sync state before ending a session |
| `/status` | Print the loop phase and project state |
| `/ship` | Final pre-merge GO/NO-GO checklist |

## Scripts

| Script | Purpose |
|---|---|
| `scripts/install.sh` | One-shot setup (idempotent) |
| `scripts/validate.sh` | The gate: format, lint, typecheck, test, build (auto-detected) |
| `scripts/detect-stack.sh` | Stack/package-manager detection (sourced by validate) |
| `scripts/self-check.sh` | Verify all harness pieces are present and valid |
| `scripts/mcp-catalog.json` | Curated tool → MCP-server map |

### Configuring the gate for your stack

`validate.sh` auto-detects Node (npm/pnpm/yarn), Python (pip/poetry/uv), Rust, Go,
and Makefile projects, and runs the standard scripts/targets for each. Missing
steps are skipped; a step that exists and fails makes the gate RED. To customize,
edit the `step` lines in `scripts/validate.sh` — e.g. point `test` at your exact
command, or add an integration-test stage. For a docs-only repo, set
`HARNESS_ALLOW_NO_STACK=1`.

## Staged growth path

Start minimal; add capability only when a real need appears.

**Stage 1 — Solo, single stream (day one).**
`/bootstrap` → `/loop`. One task at a time, both gates on. This alone is a complete
workflow.

**Stage 2 — Add external tools.**
When a task needs a DB, GitHub, or a browser, run `/mcp-add`. Keep it to what the
task needs.

**Stage 3 — Parallel work with worktrees.**
Once you're juggling independent features, use git worktrees (see
`docs/DEVELOPMENT_WORKFLOW.md`). Each worktree shares `CLAUDE.md` and `docs/` but has
its own auto-memory, so two loops can run without colliding.

**Stage 4 — Loosen autonomy where it's earned.**
In a well-scoped, trusted project, let the orchestrator auto-approve GATE 1 for
low-risk tasks. The validation gate stays mandatory; GATE 2 stays manual for
anything touching security or data.

**Stage 5 — Bundle & share.**
When your agent/command set stabilizes, package it as a Claude Code plugin so other
repos install it in one step, and add project-specific reviewers (e.g.
`python-reviewer`) as the codebase grows.

## Troubleshooting

- **Hooks not running?** Ensure `scripts/install.sh` ran (it `chmod +x`es hooks) and
  that you started `claude` from the repo root so `$CLAUDE_PROJECT_DIR` resolves.
- **Gate always RED with "no-stack"?** Your stack isn't auto-detected — configure
  `scripts/validate.sh`, or set `HARNESS_ALLOW_NO_STACK=1` for a docs-only repo.
- **An agent isn't triggering?** Its description may overlap another's. Make the
  descriptions distinct, and restart the session to reload edited agent files.
- **MCP server won't connect?** Validate `.mcp.json` (`python3 -m json.tool .mcp.json`),
  confirm the env vars are set, and restart Claude Code.
