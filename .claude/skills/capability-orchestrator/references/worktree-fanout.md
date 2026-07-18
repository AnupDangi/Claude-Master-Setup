# Worktree fan-out — operator guide

Use when GATE 1 approved a file-disjoint `fanout` map for one BUILD.
Script: `scripts/worktree-fanout.sh`.

## When to fan out

Do fan out when:

- Slices own **disjoint** file paths
- Each slice has (or will have) its own tests
- Parallelism would shorten wall time

Do **not** fan out when two slices would edit the same router, schema, or shared
module — serialize instead.

## Manifest example

```json
{
  "base_branch": "feat/reset-password",
  "worktree_root": "../myproj-fanout",
  "max_parallel": 3,
  "slices": [
    {
      "id": "api",
      "title": "Reset API",
      "branch": "fanout/api",
      "files": ["src/routes/reset.ts", "tests/reset.test.ts"]
    },
    {
      "id": "ui",
      "title": "Reset form",
      "branch": "fanout/ui",
      "files": ["src/ui/ResetForm.tsx", "tests/ResetForm.test.tsx"]
    }
  ]
}
```

Hard cap: `HARNESS_MAX_PARALLEL_IMPLEMENTER` (default 5). The script rejects
overlapping `files` and too many slices.

## Commands

```bash
# From repo root (integration branch)
bash scripts/worktree-fanout.sh create manifest.json
bash scripts/worktree-fanout.sh status manifest.json

# After children commit on their branches (ff-first for linear history):
bash scripts/worktree-fanout.sh merge manifest.json

# After COMMIT (production default — removes worktrees AND deletes slice branches):
bash scripts/worktree-fanout.sh cleanup manifest.json
# Debug only — keep slice branches:
# bash scripts/worktree-fanout.sh cleanup manifest.json --keep-branches
```

`create` also writes `manifest.runtime.json` with resolved paths.

## Parent implementer checklist

1. Materialize manifest from approved `fanout`
2. `create`
3. Launch ≤5 child Tasks (AGENT_TASK template + Owned Files / Do Not Touch)
4. Children: one commit per slice branch preferred
5. `merge` on integration branch
6. Report to orchestrator → integration VALIDATE
7. `cleanup` when done

## Multi-feature vs intra-task

| Mode | Mechanism | Use for |
|---|---|---|
| Multi-feature | Separate dirs each running `/loop` | Independent roadmap items |
| Intra-task | This script under one parent implementer | One approved plan, parallel slices |

See `docs/DEVELOPMENT_WORKFLOW.md` for multi-feature worktrees.
