# CLAUDE.md

Permanent memory for this repository. Every Claude Code session reads this first.
It holds **stable** knowledge only — conventions, workflow, and how this harness
operates. Anything current-state (progress, TODOs, sprint status) lives in `docs/`,
never here.

> This file ships as the **harness manual**. After you run `/bootstrap`, the
> project-specific mission, stack, and conventions get filled in below by the
> architect — but the workflow, agent, loop, and MCP sections stay as-is.

---

## What this repository is

A **self-contained Claude Code harness**: clone it, drop in requirements, and it
runs an engineered build loop — plan → build → validate → review → commit — with
specialist subagents and hard quality gates. No external plugin marketplace is
required. It works with only the files in this repo.

## Read order for every session

1. `CLAUDE.md` (this file) — conventions and workflow.
2. `docs/PROJECT_STATE.md` — where the project is right now.
3. `docs/SESSION.md` — what happened last session.
4. `docs/DECISIONS.md` — architectural decisions already made (do not re-litigate).
5. `.claude/state/loop.json` — the loop's current phase.

Treat the **repository, not the conversation**, as the source of truth.

---

## The four memory layers

Knowledge has exactly one home. Do not duplicate a fact across layers.

| Layer | Holds | Changes |
|---|---|---|
| `PRD.md` / `PTR.md` | Product & technical requirements | Rarely |
| `CLAUDE.md` | Stable conventions, workflow, harness rules | Rarely |
| `docs/` | Shared project knowledge, current state, decisions | Often |
| Claude Code auto-memory | Per-worktree learned patterns | Continuously |

If a future worktree or session must know something, it goes in `CLAUDE.md` or
`docs/` — never left only in auto-memory (which is worktree-local).

---

## The build loop

The loop is the product. Full spec in `docs/LOOP.md`. Capability layer (local
skills, hierarchical subagents, worktree fan-out) in
`docs/CAPABILITY_ORCHESTRATION.md`. One iteration:

```
SELECT → DISCOVER → PLAN → [gate: approve plan] → BUILD → VALIDATE (hard gate)
       → REVIEW → [gate: approve merge] → COMMIT → update state → LOOP
```

- Run it with `/loop`. The **orchestrator** subagent drives it and delegates.
- Commands state **intent**; orchestrator chooses skills / fan-out / specialists.
- **Two human gates** (approve the plan; approve the merge) and **one automated
  gate** (validation). None may be skipped.
- **Validation hard-blocks.** If `scripts/validate.sh` is RED, the loop returns to
  BUILD and will not advance. GREEN is binary — never "green with warnings".
- **One shippable unit per iteration.** New scope goes on the roadmap, not into the
  current task. Parallel writers only via worktrees under an approved fan-out map.


## The subagents

Defined in `.claude/agents/`. Full reference in `docs/AGENTS.md`.

| Agent | Role | Writes code? |
|---|---|---|
| `orchestrator` | Runs the loop, delegates, enforces gates | No |
| `planner` | Roadmap item → step plan + DoD | No |
| `architect` | Challenges design, writes ADRs | Docs only |
| `implementer` | Writes code **and** tests for one task (Sonnet, default) | Yes |
| `implementer-opus` | Same job, Opus tier — used instead of `implementer` when `task_complexity` is `large` | Yes |
| `validator` | Runs the gate, reports GREEN/RED | No |
| `reviewer` | Quality pass, severity-ranked | No |
| `security` | OWASP/secrets/authz pass | No |
| `docs-writer` | Keeps docs synced | Docs only |
| `mcp-scout` | Finds & adds MCP servers (with consent) | `.mcp.json` only |
| `evaluator` | Objective-metrics scorecard (`/evaluate`) | No |

## Slash commands

`/bootstrap` `/loop` `/plan` `/validate` `/review` `/mcp-add` `/handoff`
`/status` `/ship` `/evaluate` — defined in `.claude/commands/`, documented in
`docs/SETUP.md`. Brownfield bootstrap: `docs/BROWNFIELD.md`. AI OS control
plane (events, leases, budget, scorecard): `docs/AI_OS.md`. Build-effort dial
(fast vs rigorous from PRD/PTR): `docs/BUILD_EFFORT.md`.

## MCP tools

When the project needs an external service (DB, GitHub, browser, payments…), use
`/mcp-add`. The **mcp-scout** checks `scripts/mcp-catalog.json`, then the web, and
asks before wiring anything into `.mcp.json`. Rules: secrets are always `${ENV_VAR}`
references (never literals), servers are least-privilege, and you must restart
Claude Code to connect a newly added server. Details in `docs/MCP.md`.

---

## Model routing

Use the cheapest model that can do the task well.

- **Haiku** — docs, formatting, status, small mechanical edits.
- **Sonnet** — features, implementation, validation, reviews, normal engineering.
- **Opus** — architecture, security review, planning, complex debugging, high-impact
  decisions.

Agent frontmatter already pins each agent to a sensible model; escalate only when
complexity justifies the cost. Full tiering table and the target (dynamic,
scheduler-driven) design in [`docs/MODEL_ROUTING.md`](docs/MODEL_ROUTING.md).

## Git & branching

- Small, atomic commits — one logical change each. Conventional Commit messages:
  `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
- One branch per feature/fix. For parallel work, use git worktrees (see
  `docs/DEVELOPMENT_WORKFLOW.md`) so independent tasks never collide.
- Never force-push a shared branch (the harness blocks it).
- Never commit secrets or `.env`.

## Definition of Ready (before BUILD)

- The task is a single shippable unit with a clear DoD.
- Files to touch are identified; no ambiguity blocking a start.
- Any needed external tool is either available or queued via `/mcp-add`.

## Definition of Done (before COMMIT)

- Code **and** tests written; `scripts/validate.sh` is GREEN.
- Reviewer (and security, if relevant) findings resolved — no open Critical/High.
- Docs updated: `PROJECT_STATE.md`, `CHANGELOG.md`, and any changed surface doc.
- Commit is atomic with a conventional message.

---

## Repository rules

**Never:**
- Duplicate business logic, or bypass an existing security boundary.
- Advance the loop past a RED validation gate, or weaken a check to make it pass.
- Redesign approved architecture without an ADR and approval.
- Introduce breaking changes silently, or add dependencies without justification.
- Assume ambiguous requirements — ask.
- Leave debug prints / `console.log` in committed code.
- Commit secrets; hardcode credentials instead of using env vars.

**Always:**
- Keep docs synchronized with implementation, in the same iteration.
- Create or update tests with every code change.
- Explain the real trade-off behind a design choice.
- Think production-first; prefer the simplest design that meets the stated scale.
- Generate `docs/HANDOFF.md` before ending a working session (`/handoff`).

---

## Working instructions for Claude

1. Start from the repository, not memory of past chats.
2. Prefer delegating to the specialist subagent for the phase you're in.
3. Track multi-step work with TodoWrite so it survives compaction.
4. When you learn something durable (a pattern, a gotcha), promote it into `docs/`
   or `CLAUDE.md` — don't leave it only in auto-memory.
5. Stop at gates. Ask when unsure. Small steps, always validated.

<!-- BOOTSTRAP FILL-IN (architect completes these after /bootstrap) -->
## Project mission
_(filled in by /bootstrap from PRD.md)_

## Architecture overview
_(filled in by /bootstrap — see docs/ARCHITECTURE.md for detail)_

## Technology stack
_(filled in by /bootstrap)_

## Coding standards
_(summary here; full detail in docs/CODING_STANDARDS.md)_
