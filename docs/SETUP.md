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

## Worked example: your first feature, end to end

A concrete walkthrough, using a toy example — a CLI word-counter.

**1. Write `PRD.md` / `PTR.md`** — a few paragraphs each, not a spec document:

```markdown
# PRD.md
## Problem
Need a CLI that counts words/lines/chars in a text file, like `wc`.
## Users
Developers running it from the terminal.
## Must-have
- `wordcount <file>` prints word/line/char counts
- Handles a missing file with a clear error
## Out of scope
- Piping stdin, multiple files, JSON output
```

```markdown
# PTR.md
## Stack
Python 3.11, stdlib only (argparse), pytest for tests.
## Constraints
Single small package, no external dependencies.
```

**2. `/bootstrap`** — `architect` reads both files, may ask a clarifying
question or two (e.g. "missing file: exit 1 or 2?"), then writes `CLAUDE.md`'s
project sections (previously templates), `docs/ARCHITECTURE.md`,
`docs/CODING_STANDARDS.md`, `docs/TESTING.md`, and `docs/ROADMAP.md` — e.g.:

```
## Milestone 1 — Core counting
- [ ] Parse CLI args, read file, print word/line/char counts
- [ ] Handle missing file: exit 1, clear stderr message
```

**No code exists yet.** Read what it wrote before continuing — this is the
cheapest point to correct a wrong assumption.

**3. `/loop`** — one iteration, concretely:

- **SELECT** — orchestrator picks "Parse CLI args, read file, print counts"
  (topmost unblocked), states why.
- **PLAN** — classifies it `small` (one small file, no architectural impact)
  → skips `architect`, delegates to `planner`. You get back a plan: which
  files (`wordcount/cli.py`, `wordcount/count.py`, `tests/test_count.py` —
  all new), the test cases (a known file counts correctly; an empty file
  counts as zero), and a Definition of Done (`python -m wordcount
  example.txt` prints the right counts).
- **GATE 1** — the plan above is shown to you. **You type "approve"** (or a
  correction — "also handle directories" — and it replans). Nothing is
  written until you do.
- **BUILD** — `implementer` (Sonnet — `task_complexity` was `small`, not
  `large`, so no `implementer-opus`) writes the three files together.
- **VALIDATE** — `validator` runs `scripts/validate.sh`; pytest runs; GREEN.
  (Had a test failed, you'd see a precise RED report and BUILD would retry —
  up to `HARNESS_MAX_VALIDATE_RETRIES`, default 3 — before stopping to ask
  you, rather than looping forever.)
- **REVIEW** — `reviewer` checks edge cases (0-byte file? a directory passed
  by mistake?) and reports findings, severity-ranked. No `security` this
  time — nothing here touches auth, input-trust boundaries, or secrets.
- **GATE 2** — you see the diff, the GREEN result, and the review findings.
  **You type "approve"** (or ask for a fix first).
- **COMMIT** — one commit (e.g. `feat: add wordcount CLI with counts`);
  `docs-writer` updates `docs/PROJECT_STATE.md` and `docs/CHANGELOG.md`.
- **LOOP** — back to SELECT, which now picks "Handle missing file" next.

**4. Repeat `/loop`** until the roadmap has no unblocked items. Run
`/mcp-add <tool>` the moment a task needs an external service, and
`/evaluate` any time you want an objective read on tests/docs/iteration
count instead of a vibe check.

Every feature after this one follows the same shape — see `docs/LOOP.md` for
the exact phase contract and `docs/AGENTS.md` for what each subagent does.

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
| `/evaluate` | Objective-metrics scorecard (tests, iterations, doc completeness) |

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

## Installation scope: project, user, or session

- **Project level (default).** `.claude/agents/`, `.claude/commands/`,
  `.claude/hooks/`, `.claude/settings.json`, and `scripts/` all live in the
  project repo root and apply only when Claude Code runs from there.
  Committed and shared with the team — this is what this repo ships as-is.

- **User level (global, every project).** Copy the agent and command
  definitions into your user config directory:
  ```bash
  cp .claude/agents/*.md ~/.claude/agents/
  cp .claude/commands/*.md ~/.claude/commands/
  ```
  The 11 subagents and 10 commands are now available in any project you open,
  without cloning this repo into it. `scripts/validate.sh` is stack-specific
  by nature, so it still needs to exist per-project — copy `scripts/` into
  each project you want the hard gate in, or package this whole harness as a
  Claude Code plugin (see Stage 5 below) so one `/plugin install` sets up a
  new project in a single command instead of a manual copy.

- **Session level (try before installing, or a true one-off).** Two ways,
  neither touches your global config:
  - `claude --settings .claude/settings.json` (run from this repo, or point
    at a copy of the file) loads the harness's permissions and hooks for that
    one session only.
  - Or simplest: `cd` into a clone or `git worktree add` of this repo and run
    `claude` there. Nothing is installed anywhere — the harness applies only
    because you're standing inside its directory, for as long as that
    session lasts.

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
