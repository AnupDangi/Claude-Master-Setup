# Changelog

> One entry per merged change, newest first. `docs-writer` maintains this. Follows
> the spirit of Keep a Changelog + Conventional Commits.

## [Unreleased]
### Added
- Self-contained Claude Code harness: loop, 9 subagents, 9 commands, validation gate,
  MCP scout + catalog, fail-safe hooks, and full docs.
- Validation retry cap: `HARNESS_MAX_VALIDATE_RETRIES` (default 3), `/loop
  max-retries=N`, `validate_attempts`/`max_validate_retries` in
  `.claude/state/loop.json`, and a new `await-human-on-red` phase so the loop
  escalates to a human instead of retrying BUILD→VALIDATE forever.
- Design docs for the harness's evolution into a Scheduler-driven Loop Engine:
  `docs/VISION.md`, `docs/LOOP_ENGINE.md`, `docs/STATE_ENGINE.md`,
  `docs/MODEL_ROUTING.md`, `docs/EVALUATION.md` — each explicit about what's
  built today versus target design.
- Task graph support (Milestone 1, first slice): `planner` can now emit an
  ordered sub-task graph instead of silently planning only the first slice of
  an oversized roadmap item. `loop.json` gained a `task_graph` field
  (`{ root, subtasks: [{ id, title, status }] }`). GATE 1 approves the whole
  graph's scope and order once; GATE 2 and the validation gate still apply to
  every sub-task individually.
- Cost/complexity classification (Milestone 1, first slice): the orchestrator
  now labels each task `trivial|small|medium|large` at the start of PLAN
  (`loop.json.task_complexity`), formalizing the existing "is this
  architecturally significant?" judgment call into an explicit, recorded step.
  Deliberately scoped down from a full token/time cost estimate — see
  `docs/MODEL_ROUTING.md` for why it doesn't drive model choice yet.
- Dependency-aware SELECT (Milestone 1, third slice): file order is now
  explicitly SELECT's priority signal (sizing an oversized pick moved to the
  Task Graph in a previous slice), and `docs/ROADMAP.md` items can declare
  `(depends: <other item>)` so SELECT skips a dependent item even if it wasn't
  manually marked `[!]`, stating which candidates it skipped and why. This
  also fixes the standing inconsistency between ROADMAP.md's "topmost
  unblocked" text and LOOP.md's old "smallest shippable unit" SELECT rule.
- `/evaluate` command + `evaluator` agent (Milestone 2, objective-metrics
  slice): a read-only scorecard reporting Tests (`validate.sh` GATE +
  coverage if the stack reports one), Iterations (a git-log-count proxy,
  explicitly not a true loop count), and Documentation completeness
  (fill-on-bootstrap template ratio). Manual Interventions is reported
  `not tracked` rather than estimated — the harness keeps no persistent
  event log. Subjective metrics (Planning/Architecture/Security/Performance/
  doc quality) are deliberately still out of scope this slice, per
  `docs/EVALUATION.md`'s sequencing. Agent/command counts updated to 10/10
  across README.md, CLAUDE.md, docs/AGENTS.md, docs/SETUP.md,
  `scripts/self-check.sh`.
- `npx`-installable scaffold: `package.json` + `bin/cli.js` (no dependencies).
  `npx github:AnupDangi/Claude-Master-Setup [target-dir]` copies the harness
  into a target directory (skipping anything already present) and runs
  `scripts/install.sh`. Tested end-to-end against a scratch directory; the
  result passed `scripts/self-check.sh`. Does not require publishing to the
  npm registry. `README.md` gained an alternate install path alongside
  git-clone.
- Dynamic model routing (Milestone 1, final item): new `implementer-opus`
  agent (Opus tier, identical job to `implementer`). The orchestrator's BUILD
  step now delegates to `implementer` (Sonnet, default) or `implementer-opus`
  based on `loop.json.task_complexity` (`large` → opus), never both on the
  same task. Landed at the user's explicit direction rather than gated on
  usage evidence, since that evidence-gathering mechanism (the persistent
  event log) doesn't exist yet — see `docs/DECISIONS.md` ADR-002. Agent count
  is now 11; propagated across README.md, CLAUDE.md, docs/AGENTS.md,
  docs/SETUP.md, `scripts/self-check.sh`.
- Worked-example walkthrough in `docs/SETUP.md`: a concrete PRD → `/bootstrap`
  → `/loop` iteration example (toy wordcount CLI), showing what GATE 1/GATE 2
  actually look like in practice.
- New `docs/OPERATIONS.md`: npm/npx package maintenance (local dev loop,
  versioning, what a real `npm publish` requires), how to invoke each of the
  11 agents directly vs. via auto-delegation, and an explicit safe/unsafe
  breakdown of running multiple agents at once.
- `LICENSE` (MIT) — no preference was specified, so MIT was used as the
  standard default for a small OSS CLI tool. `package.json` gained
  `license`, `author`, `keywords`, `homepage`, `bugs`. Verified via read-only
  checks (no publish performed): package name is free on the npm registry,
  `npm publish --dry-run` succeeds (71 files, ~75 kB). Publishing for real
  still needs the user's own `npm login`.

### Changed
- `docs/MODEL_ROUTING.md` corrected: verified via Claude Code docs that the
  `Task` tool has no per-call model override, so the target design is
  orchestrator-chosen named agent variants per tier, not a runtime parameter.
- `README.md` repositioned from "a Claude Code setup" to "an autonomous software
  engineering harness," with pointers to the new design docs.
- `docs/ROADMAP.md` filled in with the harness's own forward roadmap (Scheduler,
  Evaluation, Benchmarks/Templates/Marketplace as staged milestones).
- `docs/AGENTS.md` gained a "Planned roles" section describing the future
  Scheduler role.

### Decided
- ADR-001 (`docs/DECISIONS.md`): roll out the new vision docs-first, land the
  retry cap as the one real engine slice this iteration, and defer Scheduler,
  Evaluation runner, Benchmarks, and Marketplace packaging to the roadmap.
- ADR-002 (`docs/DECISIONS.md`): build dynamic model routing now, on the
  user's explicit direction rather than internally-gathered usage evidence —
  a valid basis for the decision distinct from building ahead of evidence
  with no such input.
