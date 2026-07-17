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

## Ending a session
Run `/handoff`: writes `docs/HANDOFF.md`, syncs `PROJECT_STATE.md` and `SESSION.md`.
The next session (yours or a teammate's) resumes from the repo, not the chat.
