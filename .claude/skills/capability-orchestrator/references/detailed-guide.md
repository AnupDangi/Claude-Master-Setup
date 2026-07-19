# Capability orchestration — detailed guide

This expands `.claude/skills/capability-orchestrator/SKILL.md`. Authoritative
harness spec: `docs/CAPABILITY_ORCHESTRATION.md`.

## Why this exists

The loop already plans, validates, reviews, and documents. Without this layer,
execution stays linear: one implementer, skills only if a human remembers them,
and no safe path to parallel writers. Capability orchestration adds:

1. Filesystem discovery of **local** Claude Code skills
2. Hierarchical subagents with explicit caps
3. Worktree-backed parallel BUILD (≤5)
4. A mandatory Markdown Task contract

It does **not** add a generic internet “capability search.”

## DISCOVER

```bash
bash scripts/list-local-skills.sh
bash scripts/select-skills.sh "<task text>"   # top ≤3
```

Returns JSON: `{ name, description, path, source }` where `source` is
`project` | `user` | `plugin`. Default sources include plugins
(`HARNESS_SKILLS_SOURCES=project,user,plugin`). Narrow if noisy. Cache on
`loop.json.skills_index` for the iteration. On name collision, project wins
over user over plugin. Nesting depth max = 1 (no L2 Task trees). After COMMIT,
fan-out cleanup deletes worktrees and slice branches (ff-first merges).

### Ranking skills for a Task

Score keyword overlap between (task title + plan file paths) and
(`name` + `description`). Keep top ≤3. Below a useful score → assign none.

## Task contract

Every L0/L1 Task uses `docs/templates/AGENT_TASK.md`:

- Objective, Context, Inputs, Constraints
- Relevant Skills (≤3 paths or _(none)_)
- Expected Output, Validation Requirements, Do Not
- Worktree children also: Worktree Path, Branch, Owned Files, Do Not Touch

Parents soft-check sections before spawn.

## Hierarchy

```
Orchestrator (≤3 top-level)
  ├─ Planner → ≤3 research children (read-only); skipped for trivial tasks
  ├─ Implementer parent → ≤5 worktree writer children
  ├─ Validator (usually alone)
  ├─ Reviewer + Security — parallel for medium/large; one combined Security
  │    dispatch (applies Reviewer's checklist too) for trivial/small
  └─ Docs-writer

Evaluator (standalone /evaluate) → ≤3 collectors (read-only)
```

Caps are **per parent**. Nested agents may re-select skills from the cached
index for their children; they must not invent new skill sources.

## Fan-out map

Planner emits when BUILD should parallelize:

```json
{
  "mode": "worktree",
  "max_parallel": 5,
  "slices": [
    {
      "id": "a",
      "title": "API",
      "branch": "fanout/a",
      "files": ["src/api.ts", "tests/api.test.ts"],
      "depends_on": [],
      "skills": []
    }
  ]
}
```

Rules: file-disjoint `files` lists; GATE 1 approval; no silent mid-BUILD
expansion; merge conflicts escalate to human.

## Merge & gates

| Output | Owner |
|---|---|
| Research / collector summaries | Parent agent (Markdown merge) |
| Slice branches | Parent implementer (`worktree-fanout.sh merge`) |
| Integration VALIDATE | Orchestrator (hard gate) |
| GATE 2 / final commit | Orchestrator after human approval |

Per-slice smoke tests are advisory. Only integration VALIDATE advances the loop.

## Failure handling

- Missing skill path → skip, append `skills_skipped`, continue
- Poor skill guidance → continue without it; do not rotate forever
- Merge conflict → stop; list conflict files; await human
- `validate_attempts` ≥ max → `await-human-on-red` (unchanged)

## Metrics

Persist via `scripts/loop-event.sh` / `.claude/state/events.jsonl`:
`skills_applied`, `orch_parallel`, `nested_parallel`, `worktree_fanout_size`,
`validate_attempts`, plus SELECT/PLAN/BUILD/VALIDATE/REVIEW/SECURITY/COMMIT
phase events. See `docs/AI_OS.md`.

## Related docs

- `docs/LOOP.md` — phase machine
- `docs/OPERATIONS.md` — swarm safety
- `docs/DEVELOPMENT_WORKFLOW.md` — multi-feature worktrees
- `references/worktree-fanout.md` — script usage
