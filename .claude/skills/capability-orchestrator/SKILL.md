---
name: capability-orchestrator
description: "Capability-driven orchestration for Claude Master Setup — discover local Claude Code skills, assign hierarchical subagents (orchestrator ≤3, planner/evaluator ≤3 nested, implementer ≤5 worktree writers), use structured Task prompts, and fan out BUILD via git worktrees. Use when running /loop with parallel specialists, worktree fan-out, local skill discovery, or when the user asks how to speed up implementation safely."
---

# Capability Orchestrator

Apply the harness protocol in `docs/CAPABILITY_ORCHESTRATION.md` (ADR-003).
Commands stay **intent-only**; this skill describes **how** to execute.

## Quick protocol

1. **DISCOVER** — `bash scripts/list-local-skills.sh` (project / user / plugin only).
2. **Select ≤3 skills** per Task; inject paths into `docs/templates/AGENT_TASK.md`.
3. **PLAN** — planner may spawn ≤3 read-only research Tasks; emit optional `fanout`.
4. **GATE 1** — human approves plan + fan-out map.
5. **BUILD** — single writer, or parent implementer + ≤5 worktree children via
   `scripts/worktree-fanout.sh` when slices are file-disjoint.
6. **VALIDATE** once on the merged tree (hard gate).
7. **REVIEW** — reviewer + security in parallel when both apply.
8. **GATE 2 → COMMIT → docs**.

## Caps

| Parent | Max | Env |
|---|---|---|
| Orchestrator | 3 | `HARNESS_MAX_PARALLEL_ORCH` |
| Planner | 3 | `HARNESS_MAX_PARALLEL_PLANNER` |
| Implementer | 5 (worktrees) | `HARNESS_MAX_PARALLEL_IMPLEMENTER` |
| Evaluator | 3 | `HARNESS_MAX_PARALLEL_EVALUATOR` |
| Skills / Task | 3 | `HARNESS_MAX_SKILLS_PER_TASK` |

## Hard rules

- Never search the web for skills inside the loop.
- Never run multiple writers on the same branch.
- Never skip GATE 1 / VALIDATE / GATE 2.
- Never expand fan-out beyond the approved map.

## References

- Full design: [references/detailed-guide.md](references/detailed-guide.md)
- Worktree ops: [references/worktree-fanout.md](references/worktree-fanout.md)
- Spec: `docs/CAPABILITY_ORCHESTRATION.md`
- Template: `docs/templates/AGENT_TASK.md`
