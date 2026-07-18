---
description: Start or resume the plan→build→validate→review→commit build loop
argument-hint: [optional: task] [optional: max-retries=N] [optional: max-iterations=N]
allowed-tools: Read, Grep, Glob, Task, TodoWrite, Bash(git:*), Bash(bash scripts/:*)
model: opus
---

# Build Loop

Current state:
- Loop state: !`cat .claude/state/loop.json 2>/dev/null || echo "no state yet (fresh start)"`
- Roadmap (top): !`sed -n '1,40p' docs/ROADMAP.md 2>/dev/null || echo "docs/ROADMAP.md missing — run /bootstrap first"`
- Uncommitted changes: !`git status --short 2>/dev/null | head -20`

## Your task

**Intent:** complete **one** unblocked roadmap increment (or the task named in
`$ARGUMENTS`) through a validated, reviewed, documented iteration — then **stop**.

Delegate to the **orchestrator** subagent. It owns *how*: local skill discovery,
hierarchical subagents, optional worktree fan-out, and gates — see
`docs/LOOP.md` and `docs/CAPABILITY_ORCHESTRATION.md`.

$ARGUMENTS

Rules for this run:
1. Read `CLAUDE.md`, `docs/PROJECT_STATE.md`, and `docs/DECISIONS.md` first if you haven't this session.
2. If `$ARGUMENTS` names a specific task, target that; otherwise pick the next unblocked roadmap item.
3. If `$ARGUMENTS` includes `max-retries=N`, use `N` as the validation retry cap for this run instead of `$HARNESS_MAX_VALIDATE_RETRIES` (default 3).
4. **Iteration budget (critical):** default `max-iterations=1` per `/loop` invocation (`$HARNESS_MAX_ITERATIONS_PER_RUN`, or `max-iterations=N` in `$ARGUMENTS`). After that many completed COMMIT cycles (or when a gate needs the human), **stop and report**. Do **not** grind the entire roadmap in one background run — that burns session limits and looks like a hang.
5. Honor both approval gates (plan approval, merge approval) and the hard validation gate. **Stop and wait at each gate** — do not auto-proceed. Phrases like "complete the end version", "finish everything", or "just keep going" do **not** authorize skipping GATE 1/2. For a multi-item finish request: run **one** iteration (or present a Task Graph at GATE 1), then stop and ask the human to run `/loop` again.
6. If VALIDATE goes RED `max_validate_retries` times in a row on the same task, stop looping BUILD→VALIDATE and escalate to the human (`await-human-on-red`) instead of retrying forever.
7. After each iteration, ensure `docs/PROJECT_STATE.md` and `.claude/state/loop.json` reflect reality before continuing (including `iterations_this_run` / `max_iterations_per_run`).
8. Stop when: the iteration budget is exhausted, the roadmap has no unblocked work, or a gate needs the human — whichever comes first.
9. Orchestrator must DISCOVER local skills (`scripts/list-local-skills.sh`) and wrap specialist Tasks in `docs/templates/AGENT_TASK.md`. Do not search online for skills.
