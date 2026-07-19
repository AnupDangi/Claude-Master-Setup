# Capability-Driven Orchestration

> How the harness turns command **intent** into execution: local skill discovery,
> hierarchical subagents, worktree-backed parallel BUILD, and structured Task
> prompts. Companion to [`LOOP.md`](LOOP.md) (authoritative phase machine) and
> [`OPERATIONS.md`](OPERATIONS.md) (safe parallelism).

## Built vs designed

| Piece | Status |
|---|---|
| Design + ADR-003 (this doc, caps, fan-out schema, task template) | Built |
| `scripts/list-local-skills.sh` + `select-skills.sh` | Built |
| `scripts/worktree-fanout.sh` (path/branch/merge guards) | Built |
| Orchestrator DISCOVER + hierarchical caps in agent prompts | Built |
| Mandatory `docs/templates/AGENT_TASK.md` | Built |
| Companion skill `.claude/skills/capability-orchestrator/` | Built |
| Scheduler / multi-roadmap-item ranking | Not this doc — see [`LOOP_ENGINE.md`](LOOP_ENGINE.md) |

## Lifecycle

```text
Command (intent only)
  → Understand intent
  → Discover local skills (filesystem index)
  → PLAN (planner may spawn ≤3 research subagents; skipped in favor of an
    orchestrator inline plan when task_complexity is trivial — docs/LOOP.md §PLAN)
  → GATE 1 (approve plan + optional worktree fan-out map)
  → BUILD
       implementer parent divides into ≤5 file-disjoint slices
       → create worktrees + branches
       → launch ≤5 child Tasks in parallel
       → each child uses assigned local skills
       → parent merges into integration branch
  → VALIDATE (once on merged tree — hard gate)
  → REVIEW (reviewer + security in parallel for medium/large; one combined
    security dispatch applying reviewer.md's checklist too for trivial/small
    — docs/LOOP.md §REVIEW)
  → GATE 2
  → COMMIT + docs-writer
  → update state / LOOP
```

`/evaluate` uses the same nested pattern: evaluator parent + ≤3 collectors, then
one merged scorecard.

## Concurrency caps (per parent)

| Layer | Who spawns | Default max | Env var | Children |
|---|---|---|---|---|
| L0 | Orchestrator | 3 | `HARNESS_MAX_PARALLEL_ORCH` | Top-level specialists for the current phase |
| L1 | Planner | 3 | `HARNESS_MAX_PARALLEL_PLANNER` | Read-only research / file mapping |
| L1 | Implementer (parent) | 5 | `HARNESS_MAX_PARALLEL_IMPLEMENTER` | Writers in **separate worktrees** |
| L1 | Evaluator | 3 | `HARNESS_MAX_PARALLEL_EVALUATOR` | Read-only metric collectors |
| Skills | Any assigner | 3 | `HARNESS_MAX_SKILLS_PER_TASK` | Injected into each Task prompt |

Caps are **per parent**, not global. An orchestrator holding 3 top-level Tasks may
see each of those fan out further under their own caps.

### Hard safety rules

1. Same branch / same worktree: **at most one writer**.
2. Parallel writers: **only via git worktrees** (≤5 under one implementer parent).
3. Nested children never commit past GATE 2. Parent implementer owns integration;
   orchestrator owns VALIDATE → REVIEW + SECURITY → GATE 2 → COMMIT.
4. Fan out only when slices are **file-disjoint**. Shared hot modules → serialize.
5. No mid-BUILD expansion beyond the GATE 1–approved fan-out map (deviation → stop
   for approval).

## Local skill discovery

Claude Code loads skills from the filesystem. There is no enumerate API for the
harness. Run:

```bash
bash scripts/list-local-skills.sh
bash scripts/select-skills.sh "<task text and planned files>"   # top ≤3
```

Sources (priority on name ties: project > user > plugin):

1. `.claude/skills/*/SKILL.md` — project
2. `~/.claude/skills/*/SKILL.md` — user
3. `~/.claude/plugins/**/skills/*/SKILL.md` — plugin (**opt-in**)

Default `HARNESS_SKILLS_SOURCES=project,user,plugin` so the agent auto-discovers
installed plugin skills. Narrow with e.g. `project,user` if the index is noisy.
Cap total index size with `HARNESS_SKILLS_MAX` (default 80).

**Never** search the web or marketplaces inside the loop.

### Selection

1. Prefer `scripts/select-skills.sh` (keyword overlap + source priority).
2. Keep top matches, max `HARNESS_MAX_SKILLS_PER_TASK` (default 3).
3. Below a useful score → assign none; continue with normal execution.
4. Missing or poor skill → skip, log in `loop.json.skills_skipped`, do not rotate
   endlessly.
5. Pass **only** the selected ≤3 skill paths into child Tasks — never the full index.

Orchestrator caches the index in `loop.json.skills_index` for the iteration.
Nested parents may re-select from that cache for children; children do not invent
new skill sources.

## Fan-out map (planner → GATE 1 → implementer)

When BUILD should parallelize, planner emits (alongside the normal plan):

```json
{
  "fanout": {
    "mode": "worktree",
    "max_parallel": 5,
    "slices": [
      {
        "id": "a",
        "title": "API route",
        "files": ["src/routes/reset.ts", "tests/reset.test.ts"],
        "depends_on": [],
        "skills": ["optional-skill-name"]
      }
    ]
  }
}
```

Rules:

- `mode` is always `worktree` for writer fan-out (v1).
- `max_parallel` ≤ env cap (default 5).
- Every path appears in **at most one** slice's `files` list.
- GATE 1 approves the map with the plan. Store active map in `loop.json.fanout`.
- Implementer parent uses `scripts/worktree-fanout.sh` — do not hand-roll paths.

### Merge

| Child kind | Merge owner | Mechanism |
|---|---|---|
| Read-only (planner / evaluator / reviewer) | Parent agent | Markdown summary merge |
| Writer slices | Parent implementer | `worktree-fanout.sh merge` — **fast-forward first**, else normal merge (no forced `--no-ff`) for linear history |
| Integration VALIDATE | Orchestrator | Hard gate on merged tree only; per-slice smoke is advisory |
| Post-COMMIT cleanup | Orchestrator | `worktree-fanout.sh cleanup` — removes worktrees **and** deletes slice branches by default (`--keep-branches` to retain) |

Unresolvable merge conflict → stop and escalate to human with conflict paths.

## Standard Task prompt

Every L0 and L1 Task uses [`templates/AGENT_TASK.md`](templates/AGENT_TASK.md).
Required sections: Objective, Context, Inputs, Constraints, Relevant Skills,
Expected Output, Validation Requirements, Do Not.

Worktree children also require: Worktree Path, Branch, Owned Files, Do Not Touch.

## State fields

See [`STATE_ENGINE.md`](STATE_ENGINE.md). Capability fields on `loop.json`:

- `skills_index` — cached discovery result (or `null`)
- `skills_assigned` — skills attached to the current top-level Tasks
- `skills_skipped` — skills that matched but were unavailable/dropped
- `fanout` — active fan-out map + worktree paths, or `null`

## Commands stay intent-only

`/loop`, `/plan`, `/evaluate` describe **what** to achieve. **How** (skills,
fan-out, nested subagents) is decided by orchestrator + specialists per this doc.

## Production readiness & failure modes

Designed for graceful degradation (agents fail unexpectedly — fail safe):

| Failure | Behavior |
|---|---|
| `list-local-skills.sh` / `select-skills.sh` errors | Continue with no skills; log skip |
| Invalid / unsafe fan-out manifest | Script exits non-zero; implementer falls back to **serial** BUILD |
| Dirty integration tree on merge | `worktree-fanout.sh merge` refuses |
| Merge conflict | Exit 2; escalate to human (`git merge --abort` if needed) |
| Nested child fails | Retry once at parent; then escalate — no infinite respawn |
| Plugin skill flood | `HARNESS_SKILLS_MAX` caps index; narrow `HARNESS_SKILLS_SOURCES` if needed |
| Unbounded agent tree | **Nesting depth max = 1** (L0→L1 only; children cannot Task-spawn) |
| Leftover fan-out branches | Auto-cleanup after COMMIT deletes worktrees + slice branches |

### Worktree script guards

`scripts/worktree-fanout.sh` enforces:

- non-empty slices; unique ids/branches; owned files required
- slice ids `[A-Za-z0-9_-]{1,64}`; safe branch names
- repo-relative file paths (no `..`, no absolute/`~` paths)
- `worktree_root` under repo `.harness-fanout/` or a **sibling** of the repo
- hard max 5 parallel slices
- merge requires clean integration worktree and no in-progress merge

### Observability (lightweight)

Per iteration, orchestrator should keep `loop.json` accurate:

- `skills_assigned` / `skills_skipped`
- `fanout` (approved map + runtime paths) while BUILD is active; clear after COMMIT

Persistent event-log metrics (`skills_applied` over time, wall-clock) remain
Backlog until a loop-history log exists.

## Related

- [`DECISIONS.md`](DECISIONS.md) ADR-003
- [`OPERATIONS.md`](OPERATIONS.md) — swarm / worktree safety
- [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md) — multi-feature worktrees
- `.claude/skills/capability-orchestrator/` — companion skill
