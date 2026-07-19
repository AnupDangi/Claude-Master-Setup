# Adaptive loop

`/loop "PROMPT" [--max-iterations N] [--completion-promise TEXT]` runs one task
until verified completion or a safety exit. The default maximum is 2.

## State machine

1. `setup-loop.sh` parses options and writes `.master/state/loop.json`.
2. A cheap classifier selects an initial `direct`, `delegated`, or `parallel` hint.
3. Up to three matching local skills are stored as paths, not expanded into context.
4. Claude inspects relevant code, refines routing, implements, and tests.
5. Validation writes `green` or `red` into loop JSON.
6. The Stop hook either completes, stops safely, or re-feeds a compact continuation.
7. Successful completion writes `.master/state/handoff.json` automatically.

Completion requires both:

- exact `<promise>TEXT</promise>` when a promise was supplied, otherwise
  `<loop-complete/>`; and
- `validation.status == "green"`.

## Routing

### Direct

For one clear, local change. No subagent is spawned.

### Delegated

For a medium feature/refactor/debug task. One implementer owns a bounded slice and
returns files, tests, and blockers.

### Parallel

For complex work that can be split safely. The planner produces dependencies and
owned files. At most three ready, file-disjoint slices run in isolated worktrees.
Slices sharing a file or interface run serially. Child agents cannot create children.

Routing hints are intentionally conservative and can be corrected after repository
inspection. Worktree fan-out is an optimization, not a requirement.

## Safety exits

- validation RED: continue/fix while iterations remain;
- maximum reached: status `max_iterations`, preserve state, stop;
- `/cancel`: status `cancelled`, preserve final state;
- `/pause`: status `paused`, record blocker;
- corrupt state/transcript: stop without an infinite loop;
- ambiguity affecting correctness: pause and ask instead of inventing architecture.

## State fields

Loop JSON stores prompt, iteration/max, completion promise, complexity, execution
mode, task graph, selected skills, assigned agents, validation, next action, pause
reason, and timestamps. Handoff JSON stores commit/branch, validation evidence,
remaining tasks, blockers, and next prompt.

## Persistent memory

Repository JSON is authoritative. After a pushed task or meaningful complex solution,
`write-handoff.py` may create `memory-pending.json`. If claude-mem is available, the
agent records that one durable observation. Missing memory tooling never blocks work.
