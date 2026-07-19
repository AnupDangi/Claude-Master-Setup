---
description: Adaptive Ralph-style loop — direct for simple work, agents for complex work
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: Read, Grep, Glob, Task, TodoWrite, Write, Edit, Bash(git:*), Bash(npm:*), Bash(pnpm:*), Bash(yarn:*), Bash(python:*), Bash(python3:*), Bash(pytest:*), Bash(cargo:*), Bash(go:*), Bash(make:*), Bash(bash */scripts/*.sh:*)
model: sonnet
---

# Adaptive Loop

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh $ARGUMENTS`

If setup prints `LOOP_NOT_STARTED` or another error, stop and show the usage; never reuse stale loop state.

Read `.master/state/loop.json`, `CLAUDE.md`, and `.master/project.json`. Do not
load a documentation bundle.

## Route this iteration

The setup script provides a cheap initial hint. Refine it after inspecting the
relevant code and update `loop.json`:

- **direct / simple** — work in this context; spawn no subagent.
- **delegated / medium** — delegate one bounded slice to `implementer` (or
  `architect` first only for a real architecture choice).
- **parallel / complex** — delegate decomposition to `planner`; create a task
  graph with dependencies and file ownership. Dispatch independent slices in
  isolated worktrees through `orchestrator`; serialize shared-file slices.

Read each path in `selected_skills` before work. Pass at most three relevant
skills to delegated tasks. Never dump the full skill index into context.

## Completion contract

1. Implement code and tests; avoid unrelated docs.
2. Run the configured validation command (normally
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh`). RED means continue/fix.
3. For important or security-sensitive changes, delegate one combined
   quality/security pass to `reviewer`; fix Critical/High findings and validate again.
4. Run `${CLAUDE_PLUGIN_ROOT}/scripts/write-handoff.py` after a completed task.
   If `memory-pending.json` exists and claude-mem is available, record that one
   durable observation; absence never blocks completion.
5. If `completion_promise` is set, output it exactly in `<promise>…</promise>`
   only when true and validation is GREEN. Otherwise output `<loop-complete/>`.
6. Stuck or ambiguous → `/pause`. Stop manually → `/cancel`.

The Stop hook will feed a compact continuation from JSON until completion or the
iteration cap (default 2).
