# Claude Master Setup

[![npm version](https://img.shields.io/npm/v/claude-master-setup?style=for-the-badge&logo=npm&logoColor=white&color=CB3837)](https://www.npmjs.com/package/claude-master-setup)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)
[![GitHub](https://img.shields.io/badge/github-AnupDangi%2FClaude--Master--Setup-181717?style=for-the-badge&logo=github)](https://github.com/AnupDangi/Claude-Master-Setup)

**Autonomous engineering harness for Claude Code** — plan, build, validate, review, and commit in a repeatable loop with specialist subagents and hard quality gates.

```bash
npx claude-master-setup
```

![Claude Master Setup demo](assets/demo.svg)

An **autonomous software engineering harness for Claude Code**. Drop in your
requirements and it plans, builds, validates, reviews, documents, and commits
work as an engineered loop — instead of a sequence of one-off prompts. The core
loop works from the files in this repo alone; optional companions (claude-mem,
superpowers, Antigravity skills) are recommended for a full Claude Code setup —
see [`docs/COMPANIONS.md`](docs/COMPANIONS.md). Full vision in
[`docs/VISION.md`](docs/VISION.md).

```
/bootstrap   # greenfield (PRD+PTR) or brownfield (existing code) → docs + roadmap
/loop        # one shippable unit per run (default); gates + budget + event log
/evaluate    # objective scorecard → feeds next SELECT
```

AI OS control plane (events, leases, budget, hard path block, harness CI):
[`docs/AI_OS.md`](docs/AI_OS.md). Build-effort dial (generic apps faster, complex
systems full rigor — review+security always): [`docs/BUILD_EFFORT.md`](docs/BUILD_EFFORT.md).

## Why it exists

Without a harness, every session re-runs the same loop by hand, and quality
depends on whoever's prompting remembering to ask for tests, review the diff,
and update the docs:

```
Prompt → Code → Prompt → Code → Prompt → Code …
```

With the harness, the same bar applies every time because it's enforced by the
loop and recorded in the repository, not held in memory of what to ask for:

```
Goal → Plan → [approve] → Build → Validate (hard gate) → Review → [approve] → Commit
```

## New to Claude? Start here

Take these three, in order, before anything else:

1. [Claude 101](https://anthropic.skilljar.com/claude-101)
2. [Claude Code 101](https://anthropic.skilljar.com/claude-code-101)
3. [Claude Code in Action](https://anthropic.skilljar.com/claude-code-in-action)

Going deeper — MCP, skills, subagents:

4. [Introduction to Model Context Protocol](https://anthropic.skilljar.com/introduction-to-model-context-protocol)
5. [Model Context Protocol: Advanced Topics](https://anthropic.skilljar.com/model-context-protocol-advanced-topics)
6. [Introduction to Agent Skills](https://anthropic.skilljar.com/introduction-to-agent-skills)
7. [Introduction to Subagents](https://anthropic.skilljar.com/introduction-to-subagents)

## Architecture 
<img width="1774" height="887" alt="image" src="https://github.com/user-attachments/assets/dbef312c-0701-411b-babf-51cf525e888b" />

## What's inside

```
CLAUDE.md                 # permanent project memory + how the harness works
MASTER-PROMPT.md          # /bootstrap (v3): build-effort → foundation (no feature code)
.claude/
├── agents/               # 11 subagents (orchestrator … evaluator)
├── commands/             # 10 slash commands (/bootstrap … /evaluate)
├── skills/               # capability-orchestrator (local skills + fan-out)
├── hooks/                # pre-bash-guard, protect-paths (control-plane), …
├── state/                # loop + events + leases + scorecard (gitignored)
└── settings.json         # acceptEdits + hooks + budget env (not a sandbox)
docs/
├── SETUP.md              # install & day-1 workflow
├── LOOP.md / AI_OS.md    # loop + event log, leases, budget
├── BUILD_EFFORT.md       # fast | standard | rigorous dial
├── BROWNFIELD.md         # bootstrap existing codebases
└── …                     # AGENTS, SECURITY, EVALUATION, ROADMAP, …
scripts/
├── validate.sh           # hard GREEN/RED gate
├── estimate-build-effort.sh
├── loop-event.sh / lease.sh / budget-check.sh / write-scorecard.sh
├── list-local-skills.sh / select-skills.sh / worktree-fanout.sh
├── self-check.sh         # verify harness wiring
└── mcp-catalog.json
.github/workflows/        # harness CI (self-check + guards)
```

No signup, no config wizard. Just files Claude Code already knows how to read.

## Quick start

Install into **Claude Code** (same UX as tools like Forge) — interactive global vs local:

```bash
# Prerequisite: Claude Code CLI must already be installed
#   npm install -g @anthropic-ai/claude-code
#   # or: brew install --cask claude-code
# Then:
npx claude-master-setup
```

```text
  Where would you like to install?

  1) Global (~/.claude) - available in all projects
  2) Local  (./.claude) - this project only

  Choice [1]:
```

Or skip the prompt:

```bash
npx claude-master-setup --global   # agents + commands → ~/.claude (all projects)
npx claude-master-setup --local    # full harness → ./.claude + scripts/docs (this repo)
```

```bash
claude                       # start Claude Code — agents/commands load automatically
# then:
/bootstrap                   # (local projects with PRD.md / PTR.md)
/loop                        # run the build loop
/status                      # where you are
```

**Global** installs agents + slash commands into `~/.claude/` and merges companion
marketplaces into `~/.claude/settings.json`. **Statusline is user-level only:**
`python3 "$HOME/.claude/statusline.sh"` (project settings must not point at
`$CLAUDE_PROJECT_DIR/.../statusline.sh`). **Local** also drops hooks,
`scripts/validate.sh`, AI OS scripts, and docs into the current repo. Re-running
is safe: existing dirs are timestamp-backed up.

### Recommended companions

`--global` / `--local` **merge** companion marketplaces + `enabledPlugins` into
`settings.json`. They do **not** spawn a shell or download plugins (keeps the
npm package free of shell/network installer behavior). Print the `claude plugin …`
commands and run them yourself (or use `/plugin` in Claude Code).

| Plugin | Why |
|---|---|
| **claude-mem** | Persistent memory across sessions |
| **superpowers** | Brainstorm / TDD / systematic debugging |
| **code-review** | Extra review depth next to `/review` |
| **antigravity-awesome-skills** | Large curated skill library |

Details: [`docs/COMPANIONS.md`](docs/COMPANIONS.md). Restart Claude Code after
plugin install, then `/learn-codebase` once per repo (claude-mem) before `/loop`.

Scanner notes: [`docs/NPM_SECURITY.md`](docs/NPM_SECURITY.md).

Other install paths (same harness files):

```bash
# Legacy scaffold into a new folder
npx claude-master-setup --scaffold my-project

# Git clone
git clone https://github.com/AnupDangi/Claude-Master-Setup.git my-project
cd my-project && bash scripts/install.sh
```

See [`docs/OPERATIONS.md`](docs/OPERATIONS.md) and [`docs/SETUP.md`](docs/SETUP.md).
Then add your requirements and bootstrap:

```
my-project/
├── PRD.md   # Product Requirements Document
└── PTR.md   # Project Technical Requirements
```

```
/bootstrap    # build-effort estimate → architecture + docs + roadmap (no feature code)
/loop         # one shippable unit per run (default); VALIDATE + REVIEW + SECURITY
```

Day-1: [`docs/SETUP.md`](docs/SETUP.md) · What to use when: [`docs/AI_OS.md`](docs/AI_OS.md) ·
Complexity dial: [`docs/BUILD_EFFORT.md`](docs/BUILD_EFFORT.md)

## Core capabilities

**Built and working today (v0.4 / branch `v2-os`):**

- **Build loop** — SELECT → DISCOVER → PLAN → approve → BUILD → VALIDATE →
  REVIEW + SECURITY → approve → COMMIT. [`docs/LOOP.md`](docs/LOOP.md)
- **Build-effort dial** — `estimate-build-effort.sh` → `fast|standard|rigorous`
  from PRD/PTR (generic apps: thin docs / outcome-first; complex systems: full
  rigor). Review + security **always**. [`docs/BUILD_EFFORT.md`](docs/BUILD_EFFORT.md)
- **AI OS control plane** — event log, leases, budget stop, scorecard→SELECT,
  hard path + control-plane blocking, harness CI, brownfield bootstrap.
  [`docs/AI_OS.md`](docs/AI_OS.md)
- **Capability orchestration** — local skills, hierarchical caps, worktree
  fan-out. [`docs/CAPABILITY_ORCHESTRATION.md`](docs/CAPABILITY_ORCHESTRATION.md)
- **Validation retry cap** — RED → BUILD up to `HARNESS_MAX_VALIDATE_RETRIES`
  (default 3), then `await-human-on-red`.
- **Subagents** — 11 specialists. [`docs/AGENTS.md`](docs/AGENTS.md)
- **State** — `loop.json` + events/leases/scorecard + `docs/PROJECT_STATE.md`.
  [`docs/STATE_ENGINE.md`](docs/STATE_ENGINE.md)
- **Model routing** — BUILD picks `implementer` vs `implementer-opus` by
  `task_complexity`. [`docs/MODEL_ROUTING.md`](docs/MODEL_ROUTING.md)
- **`npx`-installable** — `--global` / `--local` / `--scaffold`.
- **MCP discovery** — `/mcp-add`. [`docs/MCP.md`](docs/MCP.md)
- **Task graphs + dependency-aware SELECT** — `(depends: …)` on roadmap items.
- **`/evaluate`** — objective scorecard (tests, loop-event iterations, docs
  completeness, manual interventions from event log) → SELECT bias.
  [`docs/EVALUATION.md`](docs/EVALUATION.md)

**Still backlog** ([`docs/ROADMAP.md`](docs/ROADMAP.md)):

- Full Scheduler (value/risk ranking across many items)
- Subjective evaluation metrics
- Benchmark suite / plugin marketplace packaging (Milestone 3)

## The build loop

The loop is the product. Full spec in [`docs/LOOP.md`](docs/LOOP.md); target
architecture in [`docs/LOOP_ENGINE.md`](docs/LOOP_ENGINE.md). It has been run
end-to-end with real subagents against a throwaway project — see
[`docs/VALIDATION.md`](docs/VALIDATION.md) for what was tested and the
honest limitations found.

```
SELECT → DISCOVER → PLAN → [approve] → BUILD → VALIDATE (hard gate)
       → REVIEW + SECURITY → [approve] → COMMIT → update docs → LOOP
```

- **Two human gates** + **VALIDATE** + **REVIEW** + **SECURITY** every iteration.
  None can be skipped (including on `fast` build-effort).
- Default **one COMMIT per `/loop`** (`HARNESS_MAX_ITERATIONS_PER_RUN=1`).
- **Validation hard-blocks.** RED → BUILD (retry-capped) or `await-human-on-red`.
- **One shippable unit per iteration.** Stop anytime; resume with `/loop` — the
  **repository** remembers, not the chat.

## Subagents

Eleven least-privilege specialists in `.claude/agents/` ([reference](docs/AGENTS.md)).
Only `implementer`/`implementer-opus` write feature code (never both on the
same task); the reviewers and validator are read-only; `mcp-scout` only
touches `.mcp.json`. Each runs in its own context and returns a summary,
keeping the main thread focused and cheap. Model routing is static for most
agents and dynamic for one pair — see [`docs/MODEL_ROUTING.md`](docs/MODEL_ROUTING.md).
For how to invoke any agent directly, and how (and how not) to run several at
once, see [`docs/OPERATIONS.md`](docs/OPERATIONS.md).

## Memory system

Four layers, one home per fact — see the "Four memory layers" table in
[`CLAUDE.md`](CLAUDE.md): `PRD.md`/`PTR.md` (requirements, rarely change),
`CLAUDE.md` (stable conventions), `docs/` (shared, current-state knowledge,
changes often), and Claude Code's per-worktree auto-memory (continuous, local).

**Companions** (claude-mem, superpowers, code-review, Antigravity skills) close
gaps that the harness alone does not — especially persistent memory and process
skills. `npx claude-master-setup --global` **merges companion flags into
`~/.claude/settings.json` and prints** the `claude plugin marketplace add` /
`claude plugin install` commands for you to run — it does **not** spawn those
installs itself. Manual steps: [`docs/COMPANIONS.md`](docs/COMPANIONS.md).

Pair with the harness:

- After `/bootstrap` (or when adopting an existing project), run
  `/learn-codebase` once so claude-mem has full repo context from day one.
- Keep using `docs/PROJECT_STATE.md`, `docs/SESSION.md`, and `docs/DECISIONS.md`
  as the **durable, reviewable** source of truth — claude-mem is a low-friction
  recall layer on top of those, not a replacement.
- Use Antigravity / superpowers skills when the task matches; use `/loop` for
  the engineered build cycle.
## Adding tools (MCP)

When a task needs an external service, run `/mcp-add <tool>`. The **mcp-scout** checks
`scripts/mcp-catalog.json`, then the web, and **asks before** wiring anything into
`.mcp.json` — always with `${ENV_VAR}` references (never literal secrets) and
least-privilege scopes. Details in [`docs/MCP.md`](docs/MCP.md).

```
/mcp-add postgres     # → "add the Postgres MCP server? it needs DATABASE_URL"
```

## Parallel work: git worktrees

Once you're juggling independent features, run each in its own worktree:

```bash
git worktree add ../myproj-payments feat/payments
cd ../myproj-payments && claude    # its own loop, shared docs/, isolated auto-memory
```

Two loops run without colliding. See [`docs/DEVELOPMENT_WORKFLOW.md`](docs/DEVELOPMENT_WORKFLOW.md).

## Installation scope: project, user, or session

Three ways to adopt this, depending on how permanent you want it:

- **Project level (default, what ships here).** `.claude/` lives in the repo
  root, committed and shared with the team. This is the only scope where
  `scripts/validate.sh` makes sense unmodified — it's written against *this*
  project's stack.
- **User level (every project, globally).** Copy `.claude/agents/*.md` and
  `.claude/commands/*.md` into `~/.claude/agents/` and `~/.claude/commands/`
  so the 11 specialists and 10 commands are available no matter which repo you
  open. `scripts/` is still per-project (it runs against that project's real
  build/test commands) — copy it into each project you want the gate in, or
  package the whole harness as a plugin (see Growth path, step 5) so
  installing it anywhere is one command.
- **Session level (try it, install nothing).** Two options: `claude
  --settings .claude/settings.json` from any directory layers in the
  harness's permissions/hooks for that session only; or simplest of all,
  just `cd` into a clone/worktree of this repo and run `claude` there —
  nothing is installed anywhere, it only applies to that directory.

Full detail in [`docs/SETUP.md`](docs/SETUP.md).

## Growth path

Start minimal, add capability only when a real need appears:

1. **Solo, single stream** — `/bootstrap` → `/loop`. A complete workflow on day one.
2. **Add tools** — `/mcp-add` when a task needs a DB, GitHub, or a browser.
3. **Parallelize** — git worktrees for independent features.
4. **Loosen autonomy carefully** — never auto-approve GATE 2 from “finish everything”;
   validation + review + security always stay on.
5. **Measure** — `/evaluate` scorecard → SELECT bias.
6. **Bundle & share** (optional) — plugin packaging; see ADR-000/001.

Full guide: [`docs/SETUP.md`](docs/SETUP.md).

## Publish (maintainers)

Branch for this release line: **`v2-os`**. Version in `package.json`: **0.4.0**.

```bash
bash scripts/self-check.sh          # must be green
git push -u origin v2-os            # when ready
npm publish --access public         # after npm login; tag optionally v0.4.0
```

Checklist: [`docs/CHANGELOG.md`](docs/CHANGELOG.md) Unreleased notes, no secrets in
the tarball (`npm pack --dry-run`), `files` in `package.json` includes scripts +
`.github/workflows` + docs.

--

Drop a 🌟 if it helped you.
