# CLAUDE.md

Permanent memory for this repository. Every Claude Code session reads this first.
It holds **stable** knowledge only — conventions, workflow, and how this harness
operates. Anything current-state (progress, TODOs, sprint status) lives in `docs/`,
never here.

> This file is the **harness source manual**. Consumer apps installed via the
> plugin get a different `CLAUDE.md` from `templates/CLAUDE.md.starter` and keep
> project memory under `.master/docs/` only (Decision 007).

---

## What this repository is

The **Claude Master Setup** harness source: agents, commands, hooks, scripts, and
docs that ship as an npm package and/or Claude Code plugin (`master` → `/master:*`).

Consumer projects do **not** clone this tree into their app. They get only
`CLAUDE.md` + `.master/` after `/master:bootstrap`. The framework lives once
(plugin cache or `~/.claude/claude-master-setup/`).

## Read order for every session (this harness repo)

1. `CLAUDE.md` (this file)
2. `docs/PROJECT_STATE.md`
3. `docs/SESSION.md`
4. `docs/DECISIONS.md` — architecture **Decisions** (do not re-litigate; supersede)
5. `.claude/state/loop.json` or `.master/state/loop.json` if present

Treat the **repository, not the conversation**, as the source of truth.

---

## The four memory layers

| Layer | Holds | Changes |
|---|---|---|
| `PRD.md` / `PTR.md` | Product & technical requirements | Rarely |
| `CLAUDE.md` | Stable conventions, workflow, harness rules | Rarely |
| `docs/` (this repo) / `.master/docs/` (consumer apps) | Shared project knowledge, Decisions, state | Often |
| Claude Code auto-memory | Per-worktree learned patterns | Continuously |

Promote durable facts into `CLAUDE.md` or `docs/` / `.master/docs/` — never leave
them only in auto-memory.

---

## The build loop

Full spec: `docs/LOOP.md`. Capability layer: `docs/CAPABILITY_ORCHESTRATION.md`.

```
SELECT → DISCOVER → PLAN → [gate: approve plan] → BUILD → VALIDATE (hard gate)
       → REVIEW + SECURITY → [gate: approve merge] → COMMIT → update state → LOOP
```

- Run with `/loop` or `/master:loop`. The **orchestrator** drives it.
- Two human gates + one automated validate gate — none may be skipped.
- Validate RED hard-blocks return to BUILD. GREEN is binary.
- One shippable unit per iteration. Confused → `/pause` (or `/master:pause`).
  Architecture change → `/decide` (supersede a Decision; never silent rewrite).

---

## The subagents

Defined in `.claude/agents/`. Reference: `docs/AGENTS.md`.

| Agent | Role | Writes code? |
|---|---|---|
| `orchestrator` | Loop, gates, working context, stop-on-ambiguity | No |
| `planner` | Roadmap item → plan + DoD | No |
| `architect` | Challenges design; writes **Decisions** | Docs only |
| `implementer` | Code + tests (Sonnet, default) | Yes |
| `implementer-opus` | Same when `task_complexity` is `large` | Yes |
| `validator` | GREEN/RED gate | No |
| `reviewer` | Quality pass | No |
| `security` | OWASP / secrets / authz | No |
| `docs-writer` | Keep docs synced | Docs only |
| `mcp-scout` | MCP servers with consent | `.mcp.json` only |
| `evaluator` | Objective scorecard (`/evaluate`) | No |

---

## Slash commands

**Core:** `/bootstrap` `/loop` `/status` `/pause` `/decide` `/handoff`  
**Power:** `/plan` `/validate` `/review` `/mcp-add` `/evaluate`

Plugin install namespaces these as `/master:bootstrap`, `/master:loop`, etc.
See `docs/SETUP.md`. Brownfield: `docs/BROWNFIELD.md`. AI OS: `docs/AI_OS.md`.
Build-effort dial: `docs/BUILD_EFFORT.md`. Shared footprint: Decision 007.

`/bootstrap` scaffolds `.master/` when missing, then runs the foundation
(MASTER-PROMPT v4). There is no separate `/init` or `/ship` command.

---

## MCP tools

Use `/mcp-add` (or `/master:mcp-add`). Secrets are always `${ENV_VAR}` references.
Details: `docs/MCP.md`. Catalog: `scripts/mcp-catalog.json`.

---

## Model routing

- **Haiku** — docs, status, small mechanical edits  
- **Sonnet** — features, validation, reviews  
- **Opus** — architecture, security, planning, high-impact Decisions  

Details: `docs/MODEL_ROUTING.md`.

## Git & branching

- Atomic conventional commits (`feat:`, `fix:`, `docs:`, …)
- One branch per feature; worktrees for parallel work (`docs/DEVELOPMENT_WORKFLOW.md`)
- Never force-push a shared branch; never commit secrets or `.env`

## Definition of Ready (before BUILD)

- Single shippable unit with clear DoD; files identified; no blocking ambiguity
- External tools available or queued via `/mcp-add`

## Definition of Done (before COMMIT)

- Code + tests; `scripts/validate.sh` GREEN
- No open Critical/High from reviewer/security
- Docs updated (`PROJECT_STATE`, `CHANGELOG`, surfaces)
- Atomic conventional commit

---

## Repository rules

**Never:** bypass security; advance past RED validate; redesign without a Decision;
assume ambiguity; commit secrets; leave debug prints.

**Always:** sync docs in the same iteration; write tests with code; stop at gates;
pause when confused; supersede Decisions via `/decide` instead of rewriting history;
prefer `/handoff` before ending a session.

---

## Working instructions for Claude

1. Start from the repository, not chat memory.
2. Delegate to the specialist for the current phase.
3. Show **working context** (phase, task, binding Decisions, next gate) each phase.
4. On ambiguity → `/pause` / `await_human_clarify` — do not invent architecture.
5. Promote durable learnings into `docs/` or `CLAUDE.md`.

<!-- BOOTSTRAP FILL-IN (architect completes these after /bootstrap on a consumer app) -->
## Project mission
_(harness source — N/A; consumer apps fill from PRD.md)_

## Architecture overview
_(see `docs/ARCHITECTURE.md` / Decision 007 shared-framework model)_

## Technology stack
_(Node ≥18 for the installer CLI; consumer stacks vary)_

## Coding standards
_(summary in `docs/CODING_STANDARDS.md`)_
