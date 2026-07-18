# Loop Engine

`docs/LOOP.md` is the authoritative spec for the loop as it exists today. This
document does two things `LOOP.md` doesn't: it draws the line between **what's
built** and **what's designed but not yet implemented**, and it specifies the
target architecture — the Scheduler — that the current loop is the first slice
of.

## What's built today

A single-task, linear state machine, run by the `orchestrator` subagent via
`/loop`:

```
SELECT → DISCOVER → PLAN → [GATE 1] → BUILD → VALIDATE (hard gate) → REVIEW + SECURITY → [GATE 2] → COMMIT → LOOP
```

- **SELECT** is one step, not a scheduler: read `docs/ROADMAP.md` +
  `docs/PROJECT_STATE.md`, scan top-to-bottom, skip `[x]`/`[!]` items and any
  item whose declared `(depends: ...)` isn't yet done, pick the first one
  left — stating what was skipped and why. File order is the priority
  signal; there's no ranking by value, risk, or any signal beyond declared
  dependencies.
- A **cost/complexity classification** runs at the start of PLAN: a coarse
  `trivial|small|medium|large` label (`loop.json.task_complexity`) — not a
  real token/time estimate. It drives two decisions: whether `architect` runs
  first, and (below) which BUILD-phase model tier is used.
- **Model choice is dynamic for one agent**: at BUILD, the orchestrator
  delegates to `implementer` (Sonnet) or `implementer-opus` (Opus) based on
  `task_complexity` (see [`MODEL_ROUTING.md`](MODEL_ROUTING.md)). Every other
  agent's model is still static, pinned per agent in frontmatter.
- **Task Graph**: when a roadmap item is too large for one iteration,
  `planner` emits an ordered sub-task graph (`loop.json.task_graph`) instead
  of silently planning only the first slice. GATE 1 approves the whole
  graph's scope once; GATE 2 and validation still apply per sub-task.
- **VALIDATE** has a real, working **retry cap**: `validate_attempts` in
  `.claude/state/loop.json` increments on each RED result; when it hits
  `max_validate_retries` (`$HARNESS_MAX_VALIDATE_RETRIES`, default 3, or
  `/loop max-retries=N`), the orchestrator stops and enters
  `await-human-on-red` instead of retrying forever.
- **State** persists in `.claude/state/loop.json`, one task at a time — see
  [`STATE_ENGINE.md`](STATE_ENGINE.md).
- There is no **Measure** step and no **Update Memory** step beyond what
  `docs-writer` already does (refresh `PROJECT_STATE.md`/`CHANGELOG.md`/
  `SESSION.md`/`DECISIONS.md`) — no scorecard, no metrics file.

## Target design: the Scheduler

The workflow above is an *engineering workflow*. The target is a **Loop
Engine**, where a Scheduler continuously decides what runs next instead of the
orchestrator picking the one topmost roadmap line:

```
Scheduler
   │
   ▼
Select Goal        — choose among unblocked roadmap items, not just the topmost one
   │
   ▼
Analyze            — read the goal, related code, and past DECISIONS.md entries
   │
   ▼
Estimate Cost       — rough token/time cost for the task, informs model choice
   │
   ▼
Choose Model        — route dynamically per task instead of a static per-agent pin
   │
   ▼
Create Plan          — same as today's PLAN phase
   │
   ▼
Generate Task Graph  — split the goal into a dependency graph, not a single unit,
                        when the planner determines it doesn't fit in one iteration
   │
   ▼
Execute              — same as today's BUILD
   │
   ▼
Validate             — same hard gate + retry cap that exists today
   │
   ▼
Review               — same as today's REVIEW
   │
   ▼
Measure              — score the iteration (see EVALUATION.md) — NOT YET BUILT
   │
   ▼
Update Memory        — beyond docs-writer's current scope: feed scores/decisions
                        back into future Select Goal / Choose Model decisions
   │
   ▼
Schedule Next
```

**Gap table:**

| Stage | Exists today | Target |
|---|---|---|
| Select | Topmost roadmap item whose `[!]` status and `(depends: ...)` annotations (if any) are satisfied; skipped candidates are stated | Scheduler ranks by value/risk signals this harness doesn't have yet, not just declared dependencies |
| Analyze | Implicit, inside PLAN | Explicit step before planning starts |
| Estimate Cost | Coarse complexity label (`trivial`\|`small`\|`medium`\|`large`) recorded in `loop.json.task_complexity`; drives the architect-invocation and BUILD-model decisions | A real token/time cost estimate, feeding model choice for every agent, not just BUILD |
| Choose Model | Built for one pair: `implementer`/`implementer-opus`, chosen by `task_complexity` (see `MODEL_ROUTING.md` — the Task tool has no runtime model override, so this means named variant files) | Same pattern extended to other agents, once each shows real evidence of needing it |
| Task Graph | Built — `planner` emits an ordered sub-task list for oversized items | Full dependency *graph* (not just an ordered list) across multiple roadmap items at once |
| Execute / Validate / Review | Built, working, gated | Unchanged — these stay as-is |
| Measure | None | `/evaluate`-style scorecard per iteration (see `EVALUATION.md`) |
| Update Memory | `docs-writer` refreshes docs/ only | Feeds structured metrics back into scheduling decisions |

`task_complexity` is deliberately a coarse label, not a real cost estimate — it
took one prompt-side rule (the "is this architecturally significant?" judgment
call orchestrator already made informally) and made it explicit and recorded.
It now drives two decisions (architect-invocation, BUILD model tier); see
`docs/MODEL_ROUTING.md` for why extending model choice beyond that one pair
still means adding real variant agent files, not a config flag.

None of the Scheduler stages beyond what's listed as "exists today" are
implemented. Treat this section as a design target that future iterations pick
off the roadmap one slice at a time — the same "one shippable unit per
iteration" rule in `CLAUDE.md` applies to building the engine itself.

## Capability-driven orchestration (built — Milestone 4)

Separate from the Scheduler target above, the harness now has a **capability
layer** on top of the existing loop (ADR-003). Full spec:
[`CAPABILITY_ORCHESTRATION.md`](CAPABILITY_ORCHESTRATION.md).

What it adds without changing the phase machine:

- **DISCOVER** — filesystem index of local Claude Code skills (project, user,
  best-effort plugins); no web/marketplace search inside the loop.
- **Hierarchical subagents** — orchestrator ≤3 top-level; planner/evaluator may
  each spawn ≤3 nested read-only children; implementer parent may spawn ≤5
  **worktree** writer children under a GATE 1–approved fan-out map.
- **Structured Task prompts** — every L0/L1 Task uses `docs/templates/AGENT_TASK.md`.
- **Worktree fan-out** — `scripts/worktree-fanout.sh`; same-branch multi-writer
  remains forbidden (`OPERATIONS.md`).

This is **built**. It is not the Scheduler (value/risk ranking across many
roadmap items) — that gap table above still applies.

## Command philosophy

Today's commands already map to complete workflows, not raw primitives:
`/bootstrap` (repository analysis → architecture → docs → roadmap) and `/loop`
(select → plan → build → validate → review → commit). Commands stay
**intent-only**; skill discovery, nested fan-out, and worktree parallelism are
orchestrator/specialist concerns (see `CAPABILITY_ORCHESTRATION.md`). Any future
`/run` command should keep that shape — one command, one complete outcome —
rather than exposing scheduler internals as separate commands a user has to
sequence by hand.
