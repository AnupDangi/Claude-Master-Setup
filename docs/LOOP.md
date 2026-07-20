# Adaptive loop

`/loop "PROMPT" [--max-iterations N] [--completion-promise TEXT]` runs one task
until verified completion or a safety exit. The default maximum is 2 iterations.


## Session memory

The loop treats `.master/state/loop.json` and `handoff.json` as durable memory across turns and sessions. Chat history is not authoritative. Each Stop-hook continuation re-reads JSON.

## Phased pipeline

Every loop iteration works through these phases:

1. **GATE** — confirm task clarity; pause with numbered questions if genuinely ambiguous
2. **PLAN** — route to direct/delegated/parallel; classify complexity; select skills
3. **BUILD** — implement code and tests; stay inside owned_files
4. **VALIDATE** — run `validate.sh`; RED means continue/fix; validator agent sets `validation.agent`
5. **REVIEW** — delegate quality/security pass to reviewer for important changes
6. **SHIP** — commit, set `ship_completed=true`, sync docs if maturity>=existing
7. **COMPLETE** — write handoff, emit `<loop-complete/>` or `<promise>TEXT</promise>`

The `phase` field in `loop.json` tracks current progress. The Stop hook enforces
all gates before accepting completion.

## State machine

1. `setup-loop.sh` parses options and writes `.master/state/loop.json`.
2. A cheap classifier selects an initial `direct`, `delegated`, or `parallel` hint.
3. Up to three matching local skills are stored as paths, not expanded into context
   (project `.claude/skills` + `.agents/skills` → `~/.claude/skills` → plugins;
   curated allowlist aliases boost ranking). `ensure-skills.sh` may install up to
   two allowlisted missing skills for the task before selection; off-allowlist
   sources are suggested to the user only.
4. Claude inspects relevant code, refines routing, implements, and tests.
5. Validation writes `green` or `red` into loop JSON.
6. The Stop hook either completes, stops safely, or re-feeds a compact continuation.
7. Successful completion writes `.master/state/handoff.json` automatically.

Completion requires all of:
- exact `<promise>TEXT</promise>` when a promise was supplied, otherwise `<loop-complete/>`;
- `validation.status == "green"`;
- `ship_completed == true`;
- for delegated/parallel: `assigned_agents` non-empty and `validation.agent == "validator"`.

## Routing

### Direct
For one clear, local change. No subagent is spawned.

### Delegated
For a medium feature/refactor/debug task. One implementer owns a bounded slice and
returns files, tests, and blockers. `assigned_agents` is populated before spawning.

### Parallel
For complex work that can be split safely. The planner produces dependencies and
owned files. At most three ready, file-disjoint slices run in isolated worktrees.
Slices sharing a file or interface run serially. Child agents cannot create children.

## Anti-stall

- Never background installs — npm/pip/cargo installs must be foreground.
- If a command fails twice with the same error, stop and report.
- Stall detection: if git status hash is identical across iterations, `stall_count` increments.
- `stall_count >= 2` triggers a pause with reason `agents_stalled`.

## Progressive docs (token economics)

Docs are loaded lazily to avoid wasting context:
- Bootstrap writes only CLAUDE.md, project.json, loop.json, optional ROADMAP.md.
- DESIGN.md is written at bootstrap for visual products only.
- API.md, DATABASE.md, SECURITY.md, TESTING.md, DEPLOYMENT.md are written at SHIP.
- `sync-project-docs.sh` runs at SHIP for maturity=existing/production projects.
- `docs.load_for_loop: false` (default) means docs are NOT preloaded into loop context.

## MCP disconnect behavior

If claude-mem is unavailable:
- `memory-pending.json` is written but no MCP call is made.
- Loop completes normally — memory absence never blocks completion.

## Safety exits

- validation RED: continue/fix while iterations remain;
- maximum reached: status `max_iterations`, preserve state, stop;
- `/cancel`: status `cancelled`, write handoff, clear validation-pending;
- `/pause`: status `paused`, record blocker, write handoff;
- corrupt state/transcript: stop without an infinite loop;
- stall detected: pause with `agents_stalled` reason;
- ambiguity affecting correctness: pause and ask instead of inventing architecture.

## State fields

Loop JSON stores: prompt, iteration/max, completion promise, complexity, execution
mode, task graph, selected skills, assigned agents, validation (status/command/agent/checks),
next action, pause reason, phase, ship_completed, correction_log,
await_clarify_questions, architecture_pending, stall_count, last_error, blocked_on,
progress_fingerprint, and timestamps.

Handoff JSON stores: commit/branch, validation evidence, phase, assigned_agents,
correction_log, stall_count, last_error, blocked_on, remaining tasks, and next prompt.
