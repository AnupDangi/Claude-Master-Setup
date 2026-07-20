---
description: Adaptive loop — direct for simple work, agents for complex work, phased pipeline with anti-stall
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: Read, Grep, Glob, Task, TodoWrite, Write, Edit, Bash(git:*), Bash(npm:*), Bash(npx:*), Bash(pnpm:*), Bash(yarn:*), Bash(python:*), Bash(python3:*), Bash(pytest:*), Bash(cargo:*), Bash(go:*), Bash(make:*), Bash(bash */scripts/*.sh:*)
model: sonnet
---

# Adaptive Loop

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh $ARGUMENTS`

If setup prints `LOOP_NOT_STARTED` or another error, stop and show the usage; never reuse stale loop state.

Read `.master/state/loop.json`, `CLAUDE.md`, and `.master/project.json`. Do not load a documentation bundle. Never background `npm/pnpm/yarn/pip/cargo` installs; run them foreground with a timeout.

## Phased pipeline

Work through these phases in order. Update `loop.json` `phase` field at each transition.

### GATE
Confirm the task is clear enough to attempt. If genuinely ambiguous about an architectural choice that affects correctness, invoke `/pause` with numbered questions. Do not pause for stylistic preferences or missing docs.

### PLAN
Route this iteration:

- **direct / simple** — work in this context; spawn no subagent.
- **delegated / medium** — delegate one bounded slice to `implementer` (or `architect` first only for a real cross-cutting architecture choice). Write an `AGENT_TASK.md` from the template at `${CLAUDE_PLUGIN_ROOT}/templates/AGENT_TASK.md`. Set `assigned_agents` in loop.json before spawning.
- **parallel / complex** — delegate decomposition to `planner`; create a dependency graph with file ownership. Dispatch independent slices in isolated worktrees through `orchestrator` (max 3 parallel). Serialize shared-file slices. Set `assigned_agents` in loop.json.

Read each path in `selected_skills` before work. Pass at most three relevant skills to delegated tasks. Never dump the full skill index into context.

**Runtime skills:** `setup-loop` already ran `ensure-skills.sh` (installs allowlisted gaps via `npx skills`). If work still needs a skill that is missing:

1. Suggest matches: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/install-skill.sh --suggest "$PROMPT"`
2. Install allowlisted skills: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/install-skill.sh <owner/repo> --skill "Name"`
3. List a repo: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/install-skill.sh --list <owner/repo>`
4. For sources **outside** the allowlist, do **not** auto-install — show the user:
   `npx skills add owner/repo --skill "Skill Name" -g -a claude-code -y --copy`
   and continue only after they approve / install.

### BUILD
Implement code and tests. Stay inside `owned_files` when delegating. Never spawn nested agents unless you are orchestrator dispatching implementers. Do not claim implementation is done without running at least focused tests.

### VALIDATE
Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh`. RED means continue/fix — do not skip or weaken. The validator agent MUST set `validation.agent = "validator"` in loop.json. Never mark GREEN without running the configured command.

### REVIEW
For important or security-sensitive changes, delegate one combined quality/security pass to `reviewer`. Fix Critical/High findings. Re-run VALIDATE after fixes.

### SHIP
Commit changes (atomic conventional commits, no credentials). Update `ship_completed: true` in loop.json. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync-project-docs.sh` if it exists and the project has maturity `existing` or `production`. Append entries to `API.md` or `DATABASE.md` when you touched routes or schema.

### COMPLETE
Run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/write-handoff.py "${CLAUDE_PROJECT_DIR:-$PWD}"` to write handoff.json. If `memory-pending.json` exists and claude-mem is available, record that one durable observation; absence never blocks completion. If `completion_promise` is set, output it exactly in `<promise>…</promise>` only when true and validation is GREEN. Otherwise output `<loop-complete/>`.

## Anti-stall rules

- Never background installs: `npm install`, `pnpm install`, `yarn install`, `pip install`, `cargo fetch` must be foreground with timeout.
- If a command fails twice with the same error, stop retrying and report the blocker.
- If blocked >60s waiting for a process, kill it and report.
- If `stall_count >= 2`, invoke `/pause` — do not spin on the same approach.
- Never invent architecture not grounded in the repo.
- Never claim validation GREEN without running the command.

## assigned_agents requirement

For `delegated` or `parallel` execution: you MUST populate `assigned_agents` in loop.json before any Task is spawned. The Stop hook will reject completion if execution_mode is not direct and `assigned_agents` is empty.

## Steer and resume

- On steer (existing active loop): a correction was appended to `correction_log`; adjust course and continue from current phase.
- On resume (paused loop): re-read `architecture_pending` and `await_clarify_questions`; address them before proceeding.

## Safety exits

- Stuck or ambiguous → `/pause` with concrete reason.
- Stop manually → `/cancel`.
- The Stop hook feeds a compact continuation from JSON until completion or the iteration cap using the phased pipeline, not just "implement and test".
