# State Engine

## What's built today

The loop's state lives entirely in one file, `.master/state/loop.json`
(gitignored, worktree-local), tracking exactly one active task:

```json
{
  "iteration": 7,
  "phase": "review",
  "task": "add password reset endpoint",
  "gate": "awaiting-merge-approval",
  "validate_attempts": 0,
  "max_validate_retries": 3,
  "task_complexity": null,
  "plan_source": null,
  "review_dispatch": null,
  "task_graph": null,
  "skills_index": null,
  "skills_assigned": [],
  "skills_skipped": [],
  "fanout": null,
  "iterations_this_run": 0,
  "max_iterations_per_run": 1,
  "build_effort_tier": null,
  "build_effort_score": null,
  "docs_profile": null
}
```

`phase` is a flat enum, one value at a time:

```
idle → select → plan → await-plan-approval → build → validate → review
     → await-merge-approval → commit → (back to select)
```

with one escape hatch — `await-human-on-red` — reached from `validate` when
`validate_attempts` hits `max_validate_retries` (see
[`LOOP_ENGINE.md`](LOOP_ENGINE.md)).

`task_complexity` (usually `null` between tasks) is a coarse
`trivial | small | medium | large` classification the orchestrator sets once at
the start of PLAN — see `docs/LOOP_ENGINE.md` for why this is a classification,
not the token/cost estimate the target design calls for.

`plan_source` ∈ `null | inline | planner` — `inline` only when `task_complexity`
was `trivial` and the orchestrator self-planned instead of dispatching
`planner` (see `docs/LOOP.md` §PLAN's trivial-eligibility checklist); `planner`
otherwise. Set at PLAN, cleared at next SELECT.

`review_dispatch` ∈ `null | combined | separate` — `combined` when REVIEW ran
as one `security` Task applying `reviewer.md`'s checklist too (`trivial`/
`small`); `separate` for the normal two-Task `reviewer` + `security` dispatch
(`medium`/`large`). Set at REVIEW, cleared at next SELECT.

`task_graph` (usually `null`) holds the case where `planner` split one roadmap
item into an ordered set of sub-tasks — `{ root, subtasks: [{ id, title,
status }] }`, `status` ∈ `pending | in_progress | done`. This is *not* the
multi-item lifecycle described below; it's still one roadmap item, one
`phase` value at a time — just multiple sequential passes through PLAN→
BUILD→VALIDATE→REVIEW→GATE 2→COMMIT under a single GATE 1 approval. See
`LOOP.md`'s PLAN and GATE 1 sections for the exact rules.

Capability-orchestration fields (see
[`CAPABILITY_ORCHESTRATION.md`](CAPABILITY_ORCHESTRATION.md)):

- `skills_index` — cached output of `scripts/list-local-skills.sh` for this
  iteration, or `null` when not yet discovered / cleared.
- `skills_assigned` — array of skill names (or `{name,path}` objects) attached
  to the current top-level Tasks.
- `skills_skipped` — skills that matched but were unavailable or dropped.
- `fanout` — active GATE 1–approved worktree fan-out map plus runtime paths
  from `worktree-fanout.sh`, or `null`. Cleared when BUILD finishes or the
  task is abandoned.
- `iterations_this_run` / `max_iterations_per_run` — per-`/loop` budget
  (default max 1). Prevents grinding an entire roadmap in one background
  session. See [`LOOP.md`](LOOP.md) "Iteration budget".

### Companion state (AI OS — also under `.master/state/`, gitignored)

| Path | Role |
|---|---|
| `history/events.jsonl` | Append-only loop event log (`scripts/loop-event.sh`) |
| `leases.json` | Multi-session roadmap leases (`scripts/lease.sh`) |
| `last_scorecard.json` | Last `/evaluate` result for SELECT bias (`write-scorecard.sh`) |
| `build_effort.json` | Project complexity estimate (`estimate-build-effort.sh --write`) |

`loop.json` may also hold `build_effort_tier`, `build_effort_score`, `docs_profile`
(`fast|standard|rigorous` / numeric / `thin|normal|full`). See
[`BUILD_EFFORT.md`](BUILD_EFFORT.md) and [`AI_OS.md`](AI_OS.md).

Longer-lived, human-readable project state lives in `docs/PROJECT_STATE.md`
(current status, done, in progress, next up, blocked) and `docs/ROADMAP.md`
(milestones with `[ ]` / `[~]` / `[x]` / `[!]` markers). These two together are
the actual source of truth `docs-writer` keeps in sync every iteration — the
`loop.json` phase machine tracks the mechanics of *the current iteration
only*.

## Target design: per-item lifecycle states

Today, roadmap items only have four flat markers (`[ ]`/`[~]`/`[x]`/`[!]`) and
the loop only ever tracks one task's phase at a time. The target extends this
to a lifecycle each roadmap item moves through, so a future Scheduler (see
`LOOP_ENGINE.md`) can reason about many items at once instead of one:

```
Pending → Planning → Executing → Validating → Reviewing → Completed
```

with two off-ramps reachable from any state:

```
Blocked     — waiting on a human decision, an external dependency, or a design call
Cancelled   — decided against; kept in the roadmap history, not deleted
```

This is a superset of the current `loop.json` `phase` enum — `Executing` maps
to `build`, `Validating` maps to `validate` (with `await-human-on-red` as a
sub-state of `Blocked`), `Reviewing` maps to `review`, and so on. The
difference is scope: `loop.json` phase applies to the one task in flight;
per-item lifecycle state would apply to *every* item in `docs/ROADMAP.md`
simultaneously, which is what a task-graph-aware Scheduler needs to decide
what to run next.

**Not yet implemented.** `docs/ROADMAP.md`'s markers stay as they are
(`[ ]`/`[~]`/`[x]`/`[!]`) until the Scheduler is actually built — don't encode
the fuller lifecycle into the roadmap file prematurely; there's nothing yet
that reads or acts on the extra states.
