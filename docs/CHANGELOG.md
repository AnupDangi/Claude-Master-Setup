# Changelog

> One entry per merged change, newest first. `docs-writer` maintains this. Follows
> the spirit of Keep a Changelog + Conventional Commits.

## [Unreleased]

### Changed
- **Shared-framework distribution model (ADR-007):** every install path
  (`--global`, `--local`, and the `master` plugin) now leaves a project with
  **only** `.master/` (state + its own docs) + `CLAUDE.md` — no `scripts/`,
  `docs/`, or `.claude/` copied per project. The framework itself
  (agents/commands/skills/scripts/docs/hooks) lives once, shared, at
  `~/.claude/claude-master-setup/` for npm installs or the plugin's own cache.
  Design verified directly against `SanthoshVishnuRajamanickam/forge-framework`
  (cloned and read in full) — `${CLAUDE_PLUGIN_ROOT}` is the one literal token
  every agent/command uses for framework-reference paths; `bin/cli.js`
  performs the identical copy-time text substitution FORGE uses for the two
  npm paths.
  - 11 scripts switched project-root resolution from `dirname "$0"` to
    `${CLAUDE_PROJECT_DIR:-$PWD}` — verified end-to-end by invoking the
    shared-location `validate.sh`/`loop-event.sh` against a separate
    sandboxed project and confirming they operated on it correctly, not on
    themselves. `self-check.sh`/`install.sh` intentionally untouched (they
    check this repo's own files, never a consumer project).
  - `.claude-plugin/plugin.json` gained a `hooks` block; `bin/cli.js` gained
    the npm-path equivalent (`$HARNESS_FRAMEWORK_ROOT`-based) — completing
    ADR-005's deferred "plugin hooks" option now that state lives in
    `.master/state/` instead of per-project `.claude/state/`.
  - `/init` (`/master:init` on the plugin) redesigned: seeds only `.master/` +
    `CLAUDE.md`, no longer copies scripts/docs/hooks.
  - New `templates/master-docs/*.md` (10 starter project-doc stubs) and
    `templates/CLAUDE.md.starter`.
  - `bin/cli.js`'s `installLocal()` now auto-installs the shared framework
    first if absent — never requires a separate `--global` run.
- Fixed a bug this same pass introduced and caught via a fresh scratch-dir
  smoke test: `self-check.sh` required `.claude-plugin/plugin.json`/
  `marketplace.json` unconditionally, which would have failed on every
  `--local` install (that path never has `.claude-plugin/`) — now skips
  gracefully when absent, validates fully when present.

### Added
- **Plugin packaging (ADR-005):** `.claude-plugin/plugin.json` (name `master`)
  + `.claude-plugin/marketplace.json` (id `claude-master-setup`) ship this
  harness as an installable Claude Code plugin:
  `claude plugin marketplace add AnupDangi/Claude-Master-Setup` then
  `claude plugin install master@claude-master-setup` gives namespaced
  `/master:loop`, `/master:bootstrap`, etc. and all 11 subagents, additive
  alongside the existing `--global`/`--local` file-copy installers.
- New `/master:init` command (`.claude/commands/init.md`): one-time,
  additive scaffold of `scripts/`, `docs/`, hooks, and state from the
  plugin's own bundle into a project that only has the plugin installed —
  bridges plugin-only installs into the project-local gated loop.
- `scripts/self-check.sh` now validates `.claude-plugin/plugin.json` and
  `marketplace.json` exist, parse, and stay version-synced with
  `package.json` — **only when present**; a `--local` file-copy install never
  has `.claude-plugin/`, so the check skips silently there instead of failing.

- **Complexity-aware ceremony dial (ADR-006):** token-efficiency pass inspired
  by a comparison against FORGE Framework, without changing the harness's
  architecture — every gate and the full swarm stay available for real work.
  - `planner` dispatch is now skipped for genuinely `trivial` tasks (a hard
    5-condition eligibility checklist in `docs/LOOP.md` §PLAN); the
    orchestrator plans inline instead, producing the identical Output
    Contract, and still stops at GATE 1 — an escape hatch resets to a real
    `planner` + fresh GATE 1 if BUILD reveals it wasn't actually trivial.
  - `reviewer`+`security` REVIEW combines into **one** Task for
    `trivial`/`small` diffs, running as the `security` persona (opus) which
    also applies `reviewer.md`'s checklist as a second **Quality Findings**
    section — preserves the higher-stakes model tier for security while
    halving dispatch count. `medium`/`large` keep both dispatches separate,
    unchanged.
  - `docs/SESSION.md` moves from "every COMMIT" to "`/handoff`-only" —
    independently correct regardless of tier, since it's a session log, not a
    commit log.
  - `fast`-tier bootstrap now **skips creating** surface docs
    (`API.md`/`DATABASE.md`/`DEPLOYMENT.md`/`OBSERVABILITY.md`) entirely when
    the PRD/PTR describe no such surface, instead of creating them thin.
  - `loop.json` gains `plan_source` and `review_dispatch` fields (seeded
    `null` in `bin/cli.js`, `scripts/install.sh`, and `.claude/commands/init.md`).
  - None of the five hard invariants (VALIDATE, REVIEW, SECURITY, GATE 1,
    GATE 2) change — only dispatch shape and doc-file count become
    complexity-aware.

### Fixed
- **`.github/workflows` no longer leaks into consumer projects.**
  `npx claude-master-setup --local` was unconditionally copying this repo's
  own `harness-ci.yml` (meta-CI for maintaining the harness itself) into
  every installed project's `.github/workflows/` — never appropriate there.
  `bin/cli.js`'s `installLocal()` no longer copies it; `scripts/install.sh`
  (git-clone path) never had this bug. `scripts/self-check.sh` no longer
  requires `.github/workflows/harness-ci.yml` as a generic "capability" (it's
  specific to this repo's own CI, not something every installed project
  needs) — confirmed via a fresh scratch-dir smoke test.

## [0.4.0] — 2026-07-19

### Added
- **Build-effort value function (ADR-004):** `scripts/estimate-build-effort.sh` +
  `docs/BUILD_EFFORT.md` — classifies projects `fast|standard|rigorous` from
  PRD/PTR/intent so generic apps get thin docs / outcome-first building, while
  complex multi-phase work keeps full harness rigor. **VALIDATE + REVIEW +
  SECURITY remain mandatory on every tier.**
- **Milestone 5 — AI OS control plane:** event log, scorecard→SELECT, harness CI,
  hard path blocking, budget stop, multi-session leases, brownfield bootstrap.
- `scripts/loop-event.sh`, `lease.sh`, `budget-check.sh`, `write-scorecard.sh`
- `docs/AI_OS.md`, `docs/BROWNFIELD.md`
- `.github/workflows/harness-ci.yml`
- npm lifecycle checks (`npm test`, `check:harness`, `prepack`) and CI package
  dry-run; recursion guard prevents self-check → validate → npm-test loops.

### Fixed
- **`--config-dir` statusline:** custom config dirs now wire `statusLine.command`
  to that directory's `statusline.sh` (no longer hardcodes `$HOME/.claude`).
- Docs/CI publish hygiene: companion install wording, OPERATIONS/ROADMAP npm
  pack facts, CI push on `v2-os`, loop diagrams include SECURITY, ADR-004 /
  AI_OS build-effort section dedupe.
- **Statusline is user-level only:** default install still runs
  `python3 "$HOME/.claude/statusline.sh"`. Project settings no longer wire
  `$CLAUDE_PROJECT_DIR/.../statusline.sh`; project name/git resolve from the
  project root.
- **/loop session-burn:** default `max-iterations=1` per invocation; orchestrator
  must not auto-approve GATE 1/2 on "finish everything"; `loop.json` tracks
  `iterations_this_run` / `max_iterations_per_run`.

### Security
- Control-plane path blocking: hooks, settings, agents, commands, `validate.sh`
  and key loop scripts require `HARNESS_ALLOW_PROTECTED_EDITS=1`.
- Hooks parse tool JSON with Python (fixes embedded-quote bypass).
- `self-check.sh` uses a private `mktemp` directory instead of predictable
  shared `/tmp` filenames.
- AI OS permissions model (`acceptEdits` + gates); allowlists are explicitly UX,
  not a same-user sandbox.
- `HARNESS_MAX_ITERATIONS_PER_RUN=1` in settings `env`.

### Changed
- `MASTER-PROMPT.md` v3: Phase 0 build effort, brownfield path, thin docs on
  `fast`, mandatory REVIEW + SECURITY.
- `README.md` refreshed for v0.4 / AI OS / publish checklist.
- Bootstrap supports brownfield (existing codebase) via `docs/BROWNFIELD.md`.
- `/evaluate` persists scorecard; Manual Interventions from event log.
- Bootstrap/architect: prefer coarse roadmaps (3–6 items for small apps).

## [0.3.0] — 2026-07-19
### Added
- **Capability-driven orchestration (ADR-003 / Milestone 4):** local skill
  discovery, hierarchical subagent caps, worktree fan-out, mandatory Task
  template, companion skill.
- `docs/CAPABILITY_ORCHESTRATION.md`, `docs/templates/AGENT_TASK.md`
- `scripts/list-local-skills.sh`, `scripts/select-skills.sh`,
  `scripts/worktree-fanout.sh`
- `.claude/skills/capability-orchestrator/` (+ references)
- `loop.json` fields: `skills_index`, `skills_assigned`, `skills_skipped`, `fanout`

### Changed
- Orchestrator / planner / implementer(-opus) / evaluator prompts: DISCOVER,
  AGENT_TASK contract, nested caps (orch ≤3 / planner ≤3 / implementer ≤5
  worktree / evaluator ≤3)
- `/loop`, `/plan`, `/evaluate` stay intent-only; execution strategy in agents
- `docs/LOOP.md`, `LOOP_ENGINE.md`, `STATE_ENGINE.md`, `OPERATIONS.md`,
  `DEVELOPMENT_WORKFLOW.md`, `AGENTS.md`, `ROADMAP.md` synced

### Security
- Production hardening: nesting depth max 1; worktree path/branch/file guards;
  merge refuses dirty trees; fan-out script failure → serial BUILD fallback; no
  full skills index dumped into child contexts

### Changed (production defaults)
- Skill DISCOVER defaults to `project,user,plugin` (agent auto-discovers plugins)
- Fan-out `merge` prefers fast-forward, else normal merge (no forced `--no-ff`)
- Fan-out `cleanup` after COMMIT deletes worktrees **and** slice branches
  (`--keep-branches` to retain for debug)

## [0.2.8] — 2026-07-18
### Added
- Project-level statusline for clones / Claude Code cloud: `.claude/settings.json`
  wires `python3 \"$CLAUDE_PROJECT_DIR/.claude/statusline.sh\"` so the bar shows
  without a global `~/.claude` install. Session + 5h/7d rate-limit bars; `--local`
  preserves an existing project statusline.

## [0.2.7] — 2026-07-18
### Added
- Ship `statusline.sh` (model / branch / project / context bar / cost). Global
  and local installs copy it into `~/.claude/` only when missing, and set
  `settings.json` `statusLine` only when unset — never overwrites an existing
  status line.

## [0.2.6] — 2026-07-18
### Fixed
- Refuse to install the harness when Claude Code (`claude`) is missing — print
  install steps and exit. Use `--force` only if you intentionally want files
  staged without the CLI.

## [0.2.5] — 2026-07-18
### Fixed
- Detect missing Claude Code CLI (`claude`) and explain that `.claude` is a
  config folder, not a command; print install steps (`npm` / Homebrew).

## [0.2.4] — 2026-07-18
### Fixed
- npm installer Socket alerts: no shell spawn / env reads in `bin/cli.js`;
  companions are settings-merge + printed `claude plugin` commands only.
  See `docs/NPM_SECURITY.md`.

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
