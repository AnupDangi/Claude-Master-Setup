# Development Workflow

> How work moves through the harness, and how to parallelize safely.

## The loop
See `docs/LOOP.md`. Day-to-day: `/loop` runs it; `/plan`, `/validate`, `/review`,
`/ship` run individual phases.

## Branching
- One branch per feature/fix: `feat/<slug>`, `fix/<slug>`.
- Conventional Commit messages (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`,
  `chore:`). Small, atomic commits.
- Never force-push a shared branch (the harness blocks it).

## Parallel work with git worktrees

Two levels of worktree use (see also
[`CAPABILITY_ORCHESTRATION.md`](CAPABILITY_ORCHESTRATION.md)):

### 1. Multi-feature: one `/loop` per worktree

Run independent features at the same time without collisions:

```bash
git worktree add ../myproj-payments feat/payments   # isolated dir + branch
cd ../myproj-payments && claude                      # its own loop
```

- Every worktree shares `CLAUDE.md` and `docs/` (committed).
- Each worktree has its own Claude Code auto-memory — worktree-local.
- Promote durable discoveries into `docs/` or `CLAUDE.md` so other worktrees see
  them. Record decisions in `DECISIONS.md`; track status in `PROJECT_STATE.md`.
- Merge each worktree back when its task is done, then `git worktree remove`.

### 2. Intra-task fan-out: parent implementer ≤5 slice worktrees

When GATE 1 approves a file-disjoint `fanout` map for one BUILD, the parent
implementer uses the harness script (do not invent paths by hand):

```bash
# manifest.json lists slices with id, branch, files
bash scripts/worktree-fanout.sh create manifest.json
bash scripts/worktree-fanout.sh status manifest.json
bash scripts/worktree-fanout.sh merge manifest.json    # ff-first into current branch
bash scripts/worktree-fanout.sh cleanup manifest.json  # after COMMIT: drops worktrees + slice branches
# bash scripts/worktree-fanout.sh cleanup manifest.json --keep-branches   # debug only
```

Children write only their owned files; parent merges (fast-forward preferred for
linear history); orchestrator VALIDATEs once, then after COMMIT cleans up
worktrees and deletes slice branches. Same-branch multi-writer remains forbidden
([`OPERATIONS.md`](OPERATIONS.md)).

## Ending a session
Run `/handoff`: writes `docs/HANDOFF.md`, syncs `PROJECT_STATE.md` and `SESSION.md`.
The next session (yours or a teammate's) resumes from the repo, not the chat.
