# The Build Loop

This harness treats development as an **engineered loop**, not a freeform chat.
Each turn of the loop produces one small, validated, reviewed, documented increment
and leaves the repository fully describing its own state. Run it with `/loop`.

```
        ┌──────────────────────────────────────────────────────────┐
        │                                                          │
        ▼                                                          │
   ┌─────────┐   ┌──────┐   ┌═══════════┐   ┌───────┐   ┌──────────┐│
   │ SELECT  │──▶│ PLAN │──▶║  GATE 1   ║──▶│ BUILD │──▶│ VALIDATE ││
   │ next    │   │      │   ║ approve   ║   │ code  │   │  (hard   ││
   │ task    │   │      │   ║ the plan  ║   │ +tests│   │   gate)  ││
   └─────────┘   └──────┘   └═══════════┘   └───────┘   └────┬─────┘│
                                                ▲            │       │
                                          RED   │            │ GREEN │
                                         (fix)  └────────────┘       │
                                                                     ▼
   ┌──────┐   ┌═══════════┐   ┌────────┐   ┌────────────────┐   ┌────────┐
   │ LOOP │◀──│ update    │◀──│ COMMIT │◀──║   GATE 2       ║◀──│ REVIEW │
   │      │   │ state/docs│   │ atomic │   ║ approve merge  ║   │ +sec   │
   └──┬───┘   └───────────┘   └────────┘   └════════════════┘   └────────┘
      │                                                             ▲
      └─────────────────────────────────────────────────────────────┘
                     (Critical/High findings loop back to BUILD)
```

## Phases

### 0. BUDGET (AI OS)
Before SELECT (and again before BUILD), run `bash scripts/budget-check.sh`.
Exit 3 → emit `budget_stop`, set phase `idle`, **stop**. Caps:
`HARNESS_MAX_ITERATIONS_PER_RUN`, `HARNESS_MAX_COMMITS_PER_DAY`,
`HARNESS_MAX_EVENTS_PER_DAY`. See [`AI_OS.md`](AI_OS.md).

Project **build-effort tier** (`fast|standard|rigorous` from
[`BUILD_EFFORT.md`](BUILD_EFFORT.md)) shapes docs depth and plan verbosity —
not whether VALIDATE / REVIEW / SECURITY run (they always do).

### 1. SELECT
If `.claude/state/loop.json` has a `task_graph` with pending sub-tasks, the
orchestrator continues it — straight to PLAN for the next sub-task, no fresh GATE 1.

Otherwise it reads `docs/ROADMAP.md`, `docs/PROJECT_STATE.md`, and optionally
`.claude/state/last_scorecard.json` (bias among unblocked items — never invent
new rows). Scan the roadmap **top-to-bottom within the current milestone**: skip
`[x]` done, skip `[!]` blocked, and skip anything whose `(depends: ...)` annotation
names another item that isn't `[x]` done yet — this catches a dependency even if
no one remembered to mark the dependent item `[!]`. Acquire a lease with
`bash scripts/lease.sh acquire "<task>"` (skip if held by another session). Emit
`select` via `loop-event.sh`. If nothing is unblocked, the loop stops and reports.

**File order is the priority signal, not size** (scorecard may re-order among
unblocked peers only). The Task Graph (see PLAN, below) owns sizing: if the item
SELECT picks turns out to be too large for one iteration, `planner` slices it.

`docs/ROADMAP.md` items may append `(depends: <other item>)` to declare an ordering
requirement beyond plain file order.

### 1b. DISCOVER (local skills)
Before PLAN detail work, the orchestrator runs `scripts/list-local-skills.sh`,
caches the index in `loop.json.skills_index`, and selects up to
`HARNESS_MAX_SKILLS_PER_TASK` (default 3) relevant **local** skills for the task.
No web or marketplace search. Full rules:
[`CAPABILITY_ORCHESTRATION.md`](CAPABILITY_ORCHESTRATION.md).

### 2. PLAN
First, the orchestrator classifies the task's rough complexity —
`trivial | small | medium | large` — in one line of reasoning, and records it in
`loop.json` as `task_complexity`. This decides whether `architect` runs first
(`large` or architecturally significant tasks do; `trivial`/`small` skip straight to
`planner`) and feeds future evaluation tracking (`docs/EVALUATION.md`). At BUILD it
also chooses `implementer` vs `implementer-opus` (see `docs/MODEL_ROUTING.md`).

Then delegates to `planner` (and `architect` first per the classification above)
using the standard Task template (`docs/templates/AGENT_TASK.md`), with the skill
shortlist in **Relevant Skills**. Planner may spawn ≤3 nested read-only research
subagents. Output: the files to touch, the tests to write, dependencies, a
Definition of Done, optional `recommended_skills`, and optional worktree
`fanout` map when BUILD should parallelize. No code is written yet.

If the roadmap item is too large for one iteration, `planner` instead returns a
**Task Graph** — the ordered list of shippable sub-tasks that together deliver it,
each with a title, one-line scope, and one-line DoD — plus a full detailed plan for
sub-task 1 only. The orchestrator stores the graph in `loop.json` under `task_graph`.
Later sub-tasks get their own fresh, detailed plan from `planner` when the
orchestrator reaches them (the repo has moved on since the graph was drawn), not all
at once up front.

### GATE 1 — approve the plan
The plan (or the whole Task Graph + sub-task 1's detailed plan, plus any worktree
`fanout` map) is presented to you in a tight summary. **The loop stops here** until
you approve. Silence is not approval. This is where you catch a wrong direction
before any code exists — the cheapest possible place to correct course.

Approving a Task Graph approves its scope and order for every sub-task in it — later
sub-tasks skip this gate and go straight from PLAN to BUILD, **unless** the fresh
detailed plan for one deviates from what the graph originally outlined. A deviation
gets its own GATE 1, scoped to just that sub-task. Approving a `fanout` map
approves those worktree slices; mid-BUILD expansion beyond the map needs a new
approval.

### 3. BUILD
Delegates to `implementer` (or `implementer-opus` when `task_complexity` is
`large`), which writes the code **and** its tests for exactly this task — nothing
more. Scope creep is rejected here.

When GATE 1 approved a worktree `fanout` map, the implementer acts as **parent**:
creates ≤5 worktrees via `scripts/worktree-fanout.sh`, launches child Tasks in
parallel (file-disjoint slices only), merges into the integration branch, then
reports merge status. Same-branch multi-writer is forbidden. See
[`CAPABILITY_ORCHESTRATION.md`](CAPABILITY_ORCHESTRATION.md).

### 4. VALIDATE — the hard gate
Delegates to `validator`, which runs `scripts/validate.sh` (format, lint, typecheck,
tests, build — auto-detected per stack).

- **GREEN (exit 0):** the gate opens; `validate_attempts` resets to 0; proceed to REVIEW.
- **RED (any non-zero):** the gate stays shut. `validate_attempts` increments and the
  failure report goes back to BUILD. Repeat BUILD → VALIDATE until GREEN **or** until
  `validate_attempts` reaches `max_validate_retries` (default 3) on this task.

GREEN is binary. There is no "green with warnings" and no skipping a check to pass.

**Retry cap.** The loop will not retry BUILD→VALIDATE forever. `max_validate_retries`
comes from `$HARNESS_MAX_VALIDATE_RETRIES` (env, default `3`) or a `/loop
max-retries=N` argument. When the cap is hit without a GREEN, the orchestrator stops
and enters `await-human-on-red`: it reports what was tried, why it kept failing, and
waits — it does not keep guessing or loosen the gate to force a pass. A human then
fixes it manually, splits the task, or explicitly raises the cap and resumes `/loop`.

### 5. REVIEW
Always delegates to `reviewer` **and** `security` in parallel (counts toward the
orchestrator's ≤3 top-level cap). Security depth may be light on pure-docs diffs;
full OWASP when auth/input/secrets/payments/uploads/network/data. Both are
read-only and return severity-ranked findings. **Critical/High findings loop back
to BUILD.** Applies on every build-effort tier (`fast` included) — see
[`BUILD_EFFORT.md`](BUILD_EFFORT.md).

### GATE 2 — approve the merge
You see the diff summary, the GREEN gate result, and the review findings. **The loop
stops here** until you approve the commit/merge.

### 6. COMMIT
One atomic commit with a conventional message. Then `docs-writer` updates
`docs/PROJECT_STATE.md`, `docs/CHANGELOG.md`, `docs/SESSION.md`, and
`docs/DECISIONS.md` (if a decision was made).

### 7. LOOP
Back to SELECT. Continue until the roadmap has no unblocked work.

## Invariants (always true between iterations)

1. The repository fully describes project state — a fresh session can continue with
   zero conversation history.
2. `main` (or the working branch) is never left with a RED gate committed.
3. Every committed code change has tests and a docs update in the same iteration.
4. `.claude/state/loop.json` reflects the true current phase.

## State file

`.claude/state/loop.json` (gitignored, worktree-local) tracks the loop:

```json
{
  "iteration": 7,
  "phase": "review",
  "task": "add password reset endpoint",
  "gate": "awaiting-merge-approval",
  "validate_attempts": 0,
  "max_validate_retries": 3,
  "task_complexity": "small",
  "task_graph": {
    "root": "add full auth system",
    "subtasks": [
      { "id": 1, "title": "password hashing util", "status": "done" },
      { "id": 2, "title": "password reset endpoint", "status": "in_progress" },
      { "id": 3, "title": "reset email template", "status": "pending" }
    ]
  },
  "skills_index": null,
  "skills_assigned": [],
  "skills_skipped": [],
  "fanout": null,
  "iterations_this_run": 0,
  "max_iterations_per_run": 1
}
```

`phase` ∈ `idle | select | plan | await-plan-approval | build | validate | review | await-merge-approval | commit | await-human-on-red`.

`validate_attempts` counts consecutive RED results on the current task since it last
left BUILD→VALIDATE; it resets to 0 on GREEN or when a new task is SELECTed.
`max_validate_retries` is seeded from `$HARNESS_MAX_VALIDATE_RETRIES` (default `3`).

`task_graph` is `null` unless `planner` split the current roadmap item into ordered
sub-tasks — see PLAN above. Each sub-task's `status` ∈ `pending | in_progress |
done`. Cleared once every sub-task is `done`.

`task_complexity` ∈ `null | trivial | small | medium | large`, set once per task at
the start of PLAN. It's a coarse classification, not a token/cost estimate — see
`docs/LOOP_ENGINE.md` for the gap between this and the target "Estimate Cost" stage.

`skills_index` / `skills_assigned` / `skills_skipped` / `fanout` support
capability-driven orchestration — see
[`CAPABILITY_ORCHESTRATION.md`](CAPABILITY_ORCHESTRATION.md) and
[`STATE_ENGINE.md`](STATE_ENGINE.md).

## Iteration budget (anti hang / anti session-burn)

Default: **one completed iteration per `/loop`**, then stop. Enforced by the
orchestrator **and** `scripts/budget-check.sh` (exit 3).

| Control | Default | Meaning |
|---|---|---|
| `max-iterations=N` on `/loop` | `1` | Max COMMIT cycles this invocation may finish |
| `$HARNESS_MAX_ITERATIONS_PER_RUN` | `1` | Same, via env |
| `$HARNESS_MAX_COMMITS_PER_DAY` | `20` | Loop-logged commits today (event log) |
| `$HARNESS_MAX_EVENTS_PER_DAY` | `200` | Event-log lines today |
| `loop.json.iterations_this_run` | `0` | Counter for the current `/loop` invocation |
| `loop.json.max_iterations_per_run` | seeded at start | Cap for this invocation |

Why: a fine-grained roadmap (e.g. 16 Flappy Bird micro-tasks) × full
PLAN→BUILD→VALIDATE→REVIEW per item can burn an hour+ and hit API session
limits while looking "stuck." That is **not** an infinite loop — it is unbounded
continuation. The budget forces a human checkpoint between shippable units.

"Complete the end version" / "finish everything" means: keep running `/loop`
(or raise `max-iterations` deliberately, e.g. `max-iterations=3`), **not**
auto-approve gates or background the whole roadmap. Full AI OS control plane:
[`AI_OS.md`](AI_OS.md).

## Autonomy dial

Default: **interactive with two approval gates** — safest, and what ships here.

**Never** treat "keep going" / "finish the game" as license to skip GATE 1 or
GATE 2. If the human wants fewer interruptions, they must say explicitly
`auto-approve-gate1` for a named low-risk task — and GATE 2 still requires a
human yes for anything beyond trivial docs. The validation gate is never
optional at any autonomy level.

## When something breaks the loop

- **Gate keeps going RED on the same failure:** the loop stops itself once
  `validate_attempts` hits `max_validate_retries` (`await-human-on-red`) — investigate
  the root cause manually (or with `/review`), and only then resume `/loop`. Do not
  loosen the check to force a pass.
- **Plan turns out wrong mid-BUILD:** implementer stops and reports; return to PLAN.
- **A task is too big:** planner returns a Task Graph instead of one plan; the loop
  works through its sub-tasks in order, one shippable unit and one GATE 2 at a time.
