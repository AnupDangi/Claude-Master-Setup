---
name: capability-orchestrator
description: "Discover local Claude Code skills, assign hierarchical subagents (orchestrator ≤3, planner/evaluator ≤3 nested, implementer ≤5 worktree writers), structure Task prompts, and fan out BUILD via git worktrees. Use for /master:loop (or /loop), parallel specialists, worktree fan-out, or local skill discovery. Do not use for one-off file edits without the loop."
---

# Capability Orchestrator

Apply `${CLAUDE_PLUGIN_ROOT}/docs/CAPABILITY_ORCHESTRATION.md` (ADR-003).
Commands stay **intent-only**; this skill describes **how** to execute.

## Quick protocol

1. **DISCOVER** — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/list-local-skills.sh"` (filesystem only: project / user / plugin skills).
2. **Select ≤3 skills** per Task; inject paths into `${CLAUDE_PLUGIN_ROOT}/docs/templates/AGENT_TASK.md`.
3. **PLAN** — planner may spawn ≤3 read-only research Tasks; emit optional `fanout`.
   Skipped for `trivial` — orchestrator plans inline (`${CLAUDE_PLUGIN_ROOT}/docs/LOOP.md` §PLAN).
4. **GATE 1** — human approves plan + fan-out map.
5. **BUILD** — single writer, or parent implementer + ≤5 worktree children via
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-fanout.sh"` when slices are file-disjoint.
6. **VALIDATE** once on the merged tree — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh"` (hard gate).
7. **REVIEW** — reviewer + security always; two parallel Tasks for medium/large, or one combined
   `security` dispatch for trivial/small.
8. **GATE 2 → COMMIT → docs-writer** (writes under `.master/docs/`).

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
- Project memory lives in `.master/docs/` + `.master/state/` — not a top-level `docs/` tree.

## References

- Full design: [references/detailed-guide.md](references/detailed-guide.md)
- Worktree ops: [references/worktree-fanout.md](references/worktree-fanout.md)
- Spec: `${CLAUDE_PLUGIN_ROOT}/docs/CAPABILITY_ORCHESTRATION.md`
- Template: `${CLAUDE_PLUGIN_ROOT}/docs/templates/AGENT_TASK.md`
