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

During an active delegated/parallel loop with empty `assigned_agents`, PreToolUse blocks product Write/Edit until a Task is spawned and `assigned_agents` is set (prep paths `loop.json`, `AGENT_TASK.md`, DESIGN/DECISIONS remain allowed).

## Routing

The initial `execution_mode` and `routing_reason` are written by `setup-loop.sh` via the signal-score classifier. The model may **downgrade** mode (parallel→delegated→direct). To upgrade, run the `planner` agent first and update `routing_reason` in `loop.json`.

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

Docs are **generated from evidence**, never bulk-copied from `templates/master-docs/`:
- Install: empty `.master/docs/` directory only
- Bootstrap: write only ROADMAP/DESIGN/DECISIONS when evidence warrants (peek outlines for headings)
- SHIP: API.md, DATABASE.md, SECURITY.md, TESTING.md, DEPLOYMENT.md via sync-project-docs.sh stubs or implementer appends
- `docs.load_for_loop: false` (default) means docs are NOT preloaded into loop context

## Runtime check (runtime_check)

When `.master/project.json` sets `runtime_check` to a non-null shell command string,
`validate.sh` runs it as a final stage after all stack checks. A non-zero exit makes
the gate RED. `null` (the default) leaves behavior unchanged from previous versions.

Set a conservative command only when an obvious smoke exists (e.g. health endpoint
curl). Leave `null` otherwise — never invent fragile checks. The harness does not
bundle Playwright or any server runner; the consumer opts in via `runtime_check`.

## Visual product gate (DESIGN.md)

At the GATE phase, if the task or repository clearly involves UI/visual work and
`.master/docs/DESIGN.md` does not exist, the loop pauses and asks the user to provide
design intent or confirm they want to continue without it. BUILD is not entered silently
for UI work without a DESIGN.md.

Bootstrap is required to create `.master/docs/DESIGN.md` for visual products before
finishing — this prevents the gate from firing on the very first loop.

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
