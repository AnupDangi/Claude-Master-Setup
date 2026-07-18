# Project State

> The first file a new session reads after `CLAUDE.md`. Updated by `docs-writer`
> after every loop iteration. Current state only — no history (that's CHANGELOG).

## Status
Harness is an autonomous software engineering / **AI OS** layer on Claude Code
(ADR-001/003). Milestones 0–2 (objective eval), 4 (capability orchestration),
and **5 (AI OS control plane)** are complete: event log, scorecard→SELECT,
harness CI, hard path blocking, budget stop, leases, brownfield bootstrap,
build-effort value function (ADR-004: `fast|standard|rigorous`).
Milestone 3 (benchmarks/plugin packaging) remains deferred. 11 agents, 10
commands, skill `capability-orchestrator`. `npx`-installable / publish-ready
pending user `npm login`.

## Done
- Self-contained loop harness: 9 agents, 9 commands, validation gate, MCP scout +
  catalog, fail-safe hooks
- Validation retry cap (`validate_attempts`/`max_validate_retries`) with
  `await-human-on-red` escalation, wired through `.claude/settings.json`,
  `.claude/commands/loop.md`, `.claude/agents/orchestrator.md`,
  `.claude/agents/validator.md`, `docs/LOOP.md`, `scripts/install.sh`
- Design docs: `docs/VISION.md`, `docs/LOOP_ENGINE.md`, `docs/STATE_ENGINE.md`,
  `docs/MODEL_ROUTING.md`, `docs/EVALUATION.md`; `docs/AGENTS.md` extended with a
  "Planned roles" section
- `README.md` repositioned to the harness vision; `docs/ROADMAP.md` filled with the
  harness's own forward roadmap (Milestones 1–3); ADR-001 recorded in
  `docs/DECISIONS.md`
- Task graph support: `planner` can emit an ordered sub-task graph
  (`loop.json.task_graph`) for roadmap items too large for one iteration; GATE 1
  approves the whole graph once, GATE 2 and validation still apply per sub-task.
  Wired through `.claude/agents/planner.md`, `.claude/agents/orchestrator.md`,
  `docs/LOOP.md`, `docs/STATE_ENGINE.md`, `scripts/install.sh`
- `docs/MODEL_ROUTING.md` corrected with a verified platform fact: the Task tool
  has no runtime model override, so "dynamic routing" means orchestrator-chosen
  named agent variants, not a per-call parameter
- Cost/complexity classification: orchestrator labels each task
  `trivial|small|medium|large` at the start of PLAN (`loop.json.task_complexity`),
  formalizing the existing architect-invocation decision. Deliberately scoped
  down from a full token-cost estimate — it does not drive model choice yet.
  Wired through `.claude/agents/orchestrator.md`, `docs/LOOP.md`,
  `docs/STATE_ENGINE.md`, `docs/LOOP_ENGINE.md`, `docs/MODEL_ROUTING.md`,
  `scripts/install.sh`
- Dependency-aware SELECT: reconciled the old "topmost unblocked" (ROADMAP.md)
  vs "smallest shippable unit" (LOOP.md) inconsistency — file order is now
  explicitly the priority signal (sizing is the Task Graph's job), and roadmap
  items can declare `(depends: <other item>)` so SELECT skips a dependent item
  even if it wasn't manually marked `[!]`, stating which candidates it skipped
  and why. Not a priority-scoring Scheduler. Wired through
  `.claude/agents/orchestrator.md`, `docs/LOOP.md`, `docs/LOOP_ENGINE.md`,
  `docs/ROADMAP.md`
- `/evaluate` + `evaluator` agent (`.claude/agents/evaluator.md`,
  `.claude/commands/evaluate.md`): objective-metrics-only scorecard — Tests
  (`validate.sh` GATE + coverage if reported), Iterations (git-log proxy),
  Documentation completeness (template-fill ratio), Manual Interventions
  reported `not tracked` (no persistent event log exists — see backlog).
  Subjective metrics (Planning/Architecture/Security/Performance/doc quality)
  deliberately not attempted this slice. Agent/command counts (10/10) updated
  across README.md, CLAUDE.md, docs/AGENTS.md, docs/SETUP.md,
  scripts/self-check.sh
- `npx`-installable scaffold: `package.json` + `bin/cli.js` (zero deps).
  `npx github:AnupDangi/Claude-Master-Setup [target-dir]` copies the harness
  files and runs `scripts/install.sh` — reuses that script rather than
  reimplementing its logic. **Actually tested end-to-end** into a scratch
  directory; the result passed `scripts/self-check.sh` cleanly. No `LICENSE`
  file exists yet and no decision has been made to publish to the npm
  registry — `npx github:...` doesn't require either.
- Ran a real `/evaluate` against this repo (not simulated): `GATE: RED` on
  Tests (expected — this repo has no downstream stack for `validate.sh` to
  check, since it IS the harness template), 18 commits (Iterations proxy),
  1/9 template docs filled (expected — those fill on `/bootstrap` for an
  adopting project, not for the harness repo itself), Manual Interventions
  `not tracked` as designed.
- Dynamic model routing (Milestone 1, final item — done, directed by the
  user rather than gated on internally-generated evidence): new
  `implementer-opus` agent (Opus tier, same job as `implementer`). Orchestrator's
  BUILD step now delegates to `implementer` (default, Sonnet) or
  `implementer-opus` based on `task_complexity` (`large` → opus). Wired
  through `.claude/agents/implementer-opus.md`, `.claude/agents/orchestrator.md`,
  `docs/MODEL_ROUTING.md`, `docs/LOOP_ENGINE.md`, `docs/ROADMAP.md`. Agent
  count now 11; propagated across README.md, CLAUDE.md, docs/AGENTS.md,
  docs/SETUP.md, scripts/self-check.sh.
- Worked-example walkthrough added to `docs/SETUP.md` — a concrete
  PRD→bootstrap→loop-iteration example (toy wordcount CLI), not just
  abstract command references.
- New `docs/OPERATIONS.md`: how to develop/version the `npx` package, how to
  invoke each agent directly, and an explicit safe-vs-unsafe breakdown of
  running multiple agents at once (parallel read-only agents and parallel
  worktrees are safe, concurrent `implementer` writers on one branch are
  not, and why).
- **npm publish readiness**: added `LICENSE` (MIT, chosen as the sensible
  default — not previously specified). `package.json` now has
  `license`/`author`/`keywords`/`repository`/`homepage`/`bugs`. Verified
  (read-only checks, no publish performed): `npm view claude-master-setup`
  → 404 (name is free), `npm whoami` → unauthenticated (confirms `npm
  login` is still the user's own step), `npm publish --dry-run` → succeeds,
  71 files, ~75 kB tarball. `docs/OPERATIONS.md` and `docs/ROADMAP.md`
  updated to reflect publish-ready-not-published status.
- `bash scripts/self-check.sh` passes with all edits applied

## Done (this iteration)
- ADR-003 + `docs/CAPABILITY_ORCHESTRATION.md` + Milestone 4 roadmap
- `scripts/list-local-skills.sh` + `scripts/worktree-fanout.sh`
- Agent/command wiring for DISCOVER, AGENT_TASK template, hierarchical caps
- Companion skill `.claude/skills/capability-orchestrator/`

## In progress
- None — Milestone 4 landed. `.claude/state/loop.json` should return to `idle`.

## Next up
1. **Persistent loop-history event log** (`docs/ROADMAP.md` Backlog) — unblocks
   Manual Interventions in `/evaluate` and feeding scores into SELECT.
2. Existing-codebase `/bootstrap` path, stack-specific reviewers, or extending
   model-routing to another agent — when real projects surface the need.
3. `npm login && npm publish` — see `docs/OPERATIONS.md`.

## Known issues / risks
- **Two roadmap items are deliberately not built**, not overlooked:
  Milestone 2's third item (needs a Scheduler-level consumer that doesn't
  exist) and all of Milestone 3 (needs Milestone 2 "trusted on real
  projects," which requires actual usage over time, not more code in one
  sitting). Forcing either now would mean shipping unproven speculative
  code — see `docs/DECISIONS.md` ADR-001's reasoning for why this repo
  stages work instead. (Milestone 1's dynamic model routing, previously in
  this category, was completed at the user's explicit direction — see the
  latest CHANGELOG entry.)
- No decision has been made to actually `npm publish` — everything short of
  that is prepared (see Status above), and it isn't required for the current
  `npx github:...` install path either way.
- The Scheduler / Benchmarks / Marketplace packaging described in the docs
  remain **designed, not implemented** where marked — `docs/LOOP_ENGINE.md` and
  `docs/EVALUATION.md` are explicit about this. Capability orchestration
  (Milestone 4 / ADR-003) **is** shipped — see
  `docs/CAPABILITY_ORCHESTRATION.md`.

- `.cursor/plans/versatile_harness_plugin_289a3e2b.plan.md` is a local,
  untracked plan file with a broader scope (existing-codebase bootstrap,
  plugin packaging, full end-to-end test rounds) than what's landed so far —
  its retry-cap idea is implemented and superseded; the rest maps onto
  `docs/ROADMAP.md` Milestones 1–3 and the Backlog but hasn't been formally
  folded in.

## Blocked / needs human
- None currently.
