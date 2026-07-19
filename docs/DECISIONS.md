# Architecture decisions

> Append-only. One entry per significant decision. The architect writes these; never
> silently reverse one — supersede it with a new Decision that references the old.

## Decision template
```
## Decision NNN: <short title>
- Date: YYYY-MM-DD
- Status: proposed | accepted | superseded by Decision XXX
- Context: what forced a decision (constraints, scale, requirements)
- Options considered: A / B / C — with the key trade-off of each
- Decision: what we chose
- Consequences: what this makes easy, what it makes hard, what we accept
```

---

## Decision 000: Adopt the self-contained loop harness
- Date: _(set on bootstrap)_
- Status: accepted
- Context: the project needs a repeatable, validated build process that any session
  can continue from the repository alone.
- Options considered: freeform chat (no structure) / external plugin harness
  (dependency + drift risk) / self-contained loop + agents in-repo.
- Decision: self-contained harness — agents, commands, hooks, and gates live in this
  repo, no external marketplace required.
- Consequences: fully portable and reviewable; the repo owns its own quality gates;
  in exchange we maintain the harness files ourselves.

## Decision 001: Reposition as an autonomous software engineering harness; roll out docs-first
- Date: 2026-07-17
- Status: accepted
- Context: the project was positioned as "a Claude Code setup" (a personal config
  people could clone). The intended long-term identity is broader — an autonomous
  software engineering harness that plans, schedules, executes, validates, measures,
  and improves itself over multiple iterations, not just a fixed plan→build→
  validate→review→commit workflow. That full vision (a Scheduler-driven task-graph
  Loop Engine, dynamic model routing, an evaluation scorecard, a benchmark suite,
  a template library, and eventual plugin/marketplace packaging) is multi-week
  scope and cannot land in one iteration without violating the "one shippable unit
  per iteration" rule this same file states below.
- Options considered:
  (A) Build the full vision immediately (scheduler, evaluation runner, benchmarks,
      marketplace) in one large pass — fast to describe, but violates the harness's
      own incremental/validated-increment principle and produces unreviewable,
      unvalidated speculative code.
  (B) Docs-first — write the design specs (`VISION.md`, `LOOP_ENGINE.md`,
      `STATE_ENGINE.md`, `MODEL_ROUTING.md`, `EVALUATION.md`) against the *current,
      real* loop, clearly separating "built today" from "target design," plus land
      one small, real, already-scoped slice of loop-engine behavior (a validation
      retry cap with human escalation) that the existing loop lacked. Defer
      Scheduler, task-graph execution, `/evaluate`, benchmarks, template library,
      and plugin/marketplace packaging to `docs/ROADMAP.md` as separate future
      iterations.
  (C) Skip the docs, just rewrite `README.md` with the new positioning — fastest,
      but leaves the vision undocumented and unreviewable as a design, and gives
      future sessions nothing concrete to build against.
- Decision: (B). Docs describe current-vs-target explicitly so nothing in this repo
  claims a capability that doesn't exist. The retry cap (`validate_attempts` /
  `max_validate_retries` in `.claude/state/loop.json`, `await-human-on-red` phase)
  is the one piece of real engine behavior added this iteration; it was already
  fully specified in a local, unimplemented plan before this decision.
- Consequences: `README.md` and the new `docs/*.md` files can now honestly describe
  both what ships today and where the project is headed, which is a precondition
  for the Marketplace stage the vision proposes without re-litigating Decision 000 (the
  self-contained-by-default decision) — Marketplace stays an optional, deferred
  growth-path stage, not a redesign of the default install. The Scheduler,
  Evaluation runner, Benchmarks, and Templates library remain unbuilt; they are
  tracked in `docs/ROADMAP.md` and must each land as their own validated
  iteration, per this harness's own rules.

## Decision 002: Build dynamic model routing on explicit user direction, not internally-gathered evidence
- Date: 2026-07-18
- Status: accepted
- Context: `docs/MODEL_ROUTING.md` and Decision 001's Milestone 1 item deferred dynamic
  model routing until there was "real evidence static routing is a problem" —
  reasoning that applied to autonomous, unprompted operation, where building ahead
  of evidence risks shipping unproven speculative code. The user then explicitly
  directed building it now ("dynamic model routing will be done by claude and
  based [on] TASK"), which is a legitimate way to supply that missing evidence —
  a product owner's direction is itself a valid basis for a scope decision, distinct
  from this repo inventing its own justification with no such input.
- Options considered:
  (A) Keep deferring, and explain to the user why — technically consistent with
      the earlier caution, but ignores that the caution was about *autonomous*
      operation lacking justification, not about overriding an explicit human
      decision once given.
  (B) Build it now, using the already-specified mechanism (`docs/MODEL_ROUTING.md`'s
      "one high-value pair" design: named per-tier variant agent files, since the
      Task tool has no runtime model override) — honors the user's direction without
      abandoning the platform-constraint-driven design already worked out.
  (C) Build a variant for every agent, not just one pair — matches "swarm"-scale
      ambition but multiplies file-maintenance cost for tiers with no evidence of
      needing it (docs-writer, validator, etc.), contradicting the "start with the
      single highest-value pair" reasoning nothing here has invalidated.
- Decision: (B). Added `implementer-opus` (Opus tier, same role as `implementer`).
  Orchestrator's BUILD step picks between them using the already-existing
  `task_complexity` classification (`large` → `implementer-opus`), escalating
  rather than downgrading — the safer direction absent usage data either way.
- Consequences: Milestone 1 is now fully done. The variant-file maintenance cost
  flagged in `MODEL_ROUTING.md` is real starting now — `implementer-opus.md` must be
  kept in sync with `implementer.md`'s conventions/rules as that file evolves.
  Extending the same pattern to another agent is Backlog work, still gated on that
  agent showing the same "most-invoked + complexity-sensitive" shape, absent a
  further explicit direction like this one.

## Decision 003: Capability-driven orchestration via local skills, hierarchical subagents, and worktree fan-out
- Date: 2026-07-19
- Status: accepted
- Context: The harness's loop, gates, and specialists were solid, but execution
  stayed linear and under-used Claude Code Skills. A generic "search everywhere"
  Capability Engine would fight the platform. Claude Code already discovers Skills
  from the filesystem and runs Subagents via Task; what was missing was an
  orchestration protocol: discover local skills, inject them into structured Task
  prompts, let running specialists spawn nested subagents, and parallelize writers
  safely. Concurrent writers on one branch remain unsafe (see `OPERATIONS.md`).
- Options considered:
  (A) Generic capability engine that searches online/skill ecosystems at runtime —
      powerful-sounding, but unbounded context, non-reproducible, and not how
      Claude Code loads skills.
  (B) Leave orchestration linear; rely on humans to invoke skills — zero harness
      change, but leaves installed skills idle and keeps BUILD serial.
  (C) Capability-driven orchestration grounded in the platform: filesystem skill
      index, hierarchical caps (orchestrator ≤3; planner/evaluator ≤3 nested;
      implementer ≤5 worktree writers), mandatory Task Markdown template, gates
      unchanged — matches real Claude Code behavior and existing worktree guidance.
- Decision: (C). Documented in `docs/CAPABILITY_ORCHESTRATION.md`. Commands stay
  intent-only; orchestrator discovers local skills only (no web/marketplace search
  inside the loop); parallel writers only via `scripts/worktree-fanout.sh` under a
  GATE 1–approved fan-out map; integration VALIDATE remains the hard gate.
- Consequences: Faster PLAN/BUILD/EVALUATE when work is file-disjoint; more agent
  and script surface to maintain (`list-local-skills.sh`, `worktree-fanout.sh`,
  companion skill). Same-branch multi-writer stays forbidden. Fan-out merges can
  conflict — parent implementer resolves or escalates to human. Scheduler-level
  multi-roadmap ranking remains out of scope (still `LOOP_ENGINE.md` target).

## Decision 004: Build-effort value function (fast vs rigorous harness dial)
- Date: 2026-07-19
- Status: accepted
- Context: Generic, previously-solved software (CLI, todo, typical ecommerce, API
  wrappers) was getting the same heavy markdown scaffolding as novel multi-phase
  systems (game clones, train+productionize LLMs). That wastes session budget on
  low-risk builds and still under-serves high-risk ones. Users need a dial based
  on *their* PRD/PTR/intent — without dropping quality gates.
- Options considered:
  (A) Always full docs harness — safe but slow for generic apps.
  (B) Always build-first — fast but skips structure when risk is high.
  (C) Estimator value function → `fast|standard|rigorous` docs/build posture;
      VALIDATE + REVIEW + SECURITY remain mandatory on every tier.
- Decision: (C). `scripts/estimate-build-effort.sh` + `docs/BUILD_EFFORT.md`;
  bootstrap runs `--write` first; human override via `HARNESS_BUILD_EFFORT_TIER`.
- Consequences: Faster outcome delivery on generic work; fuller process on hard
  work. Heuristic keywords can mis-tier — override and architect challenge fix
  that. Agents must not interpret `fast` as skipping review/security.

## Decision 005: Package as a Claude Code plugin (`master`) for namespaced `/master:*` commands
- Date: 2026-07-19
- Status: accepted
- Context: users wanted `forge-framework`-style namespaced commands
  (`/master:loop`, `/master:bootstrap`, …) instead of bare `/loop`. Research
  into Claude Code's actual behavior found that `.claude/commands/<subdir>/`
  does **not** create a namespace — that's documented but non-functional
  upstream (confirmed via a live `anthropics/claude-code` GitHub issue). The
  only real mechanism is a Claude Code **plugin**: commands/agents/skills
  shipped inside an installed plugin are automatically prefixed with the
  plugin's `name` (confirmed against the official plugin-marketplaces docs and
  by installing this repo as a plugin end-to-end in an isolated
  `CLAUDE_CONFIG_DIR` sandbox — `claude plugin validate .` passed and the
  cached install correctly contained `.claude/commands` and `.claude/agents`).
  Milestone 3 of `docs/ROADMAP.md` had already anticipated this as deferred,
  optional packaging work; this Decision pulls that one slice forward on explicit
  user direction, same pattern as Decision 002.
- Options considered:
  (A) Package as a plugin (`.claude-plugin/plugin.json` name `master` +
      `.claude-plugin/marketplace.json` id `claude-master-setup`), pointing at
      the **existing** `.claude/commands`, `.claude/agents`, `.claude/skills`
      paths in place — no repo restructuring required. Additive: the
      `npx --global`/`--local` file-copy installers are untouched and keep
      giving bare command names, so nothing breaks for existing adopters.
  (B) Same, but also ship the safety hooks and `.claude/settings.json` as
      plugin-level hooks (using `${CLAUDE_PLUGIN_ROOT}` in place of
      `$CLAUDE_PROJECT_DIR`) so gates are active immediately on plugin
      install, before any per-project scaffolding.
  (C) Rename/restructure `.claude/commands/` into subdirectories to "look"
      namespaced — rejected outright: confirmed non-functional, would be
      purely cosmetic and misleading.
- Decision: (A), with a **new `/master:init` command** as the bridge (B) would
  have needed: a plugin-only install gives you `/master:*` commands and
  subagents immediately, but the gated loop (`scripts/validate.sh`, hooks,
  `docs/` memory) is intentionally project-local (Decision 000's self-contained
  identity), so `/master:init` copies those from the plugin's own bundle
  (`${CLAUDE_PLUGIN_ROOT}`) into the current project on first use — skipping
  any file that already exists — then seeds `.claude/state/loop.json` and runs
  `self-check.sh`. Plugin-level hooks (option B) were deliberately deferred:
  wiring `$CLAUDE_PROJECT_DIR`-based hook scripts at the plugin level risks
  double-firing when a project has *both* the plugin enabled and a `--local`
  scaffold, and the hooks need per-project `.claude/state/` anyway to do
  anything useful — not a clear enough win to take on that risk in v1.
- Consequences: Three install paths now coexist: `--global`/`--local`
  (file-copy, bare command names, the unchanged default), plugin (`master`,
  namespaced commands, needs one `/master:init` per project for the full
  gate), and the legacy `--scaffold`. `scripts/self-check.sh` now also
  validates `.claude-plugin/plugin.json`/`marketplace.json` are present, valid,
  and version-synced with `package.json`, so a version bump that forgets the
  plugin manifest fails self-check instead of silently drifting. Publishing
  the marketplace publicly (pushing `AnupDangi/Claude-Master-Setup` as an
  installable source, beyond the local-sandbox test already run) remains a
  human action, same as the npm publish step. Extending hooks to the plugin
  layer (option B) stays Backlog if real usage shows the two-step
  install-then-init flow is too much friction.
- Later update (2026-07-19): `/master:init` was **removed**. Scaffolding moved
  into `/master:bootstrap` under Decision 007's shared-framework model; there
  is no separate init or ship command.

## Decision 006: Complexity-aware ceremony dial (skip `planner`, combine `reviewer`+`security`, trim doc churn) for `trivial`/`small` tasks
- Date: 2026-07-19
- Status: accepted
- Context: a comparison against FORGE Framework (a competing Claude Code
  harness) showed it ships a trivial app cheaply by running one agent through
  PLAN→APPLY→UNIFY instead of always spawning a full planner/implementer/
  reviewer/security swarm, and by writing state to disk instead of touching
  many docs per iteration. Direct repo research confirmed this harness had no
  such fast path: `task_complexity` only ever gated `architect` (`large`) and
  the `implementer`/`implementer-opus` model choice — `planner` dispatched
  unconditionally every PLAN, `reviewer`+`security` always ran as two separate
  Tasks regardless of diff size, and `docs/SESSION.md` was rewritten on every
  single COMMIT despite its own docstring calling it a *session* log. The
  explicit constraint for this change: adopt the efficiency lesson **without**
  changing the architecture — the multi-agent swarm and every hard gate must
  stay fully available for real engineering work.
- Options considered:
  (A) Leave dispatch static — matches "we don't have to change our
      architecture" literally, but leaves the confirmed token waste on every
      trivial/small task unaddressed.
  (B) Complexity-aware dispatch shape: orchestrator plans inline (no
      `planner` Task) for a narrowly-defined `trivial` tier (5-condition
      checklist: one file, no new deps/schema/API, fully pre-specified, no
      fan-out could apply); combine `reviewer`+`security` into one Task for
      `trivial`/`small`; move `docs/SESSION.md` to `/handoff`-only; skip
      creating irrelevant surface docs (`API.md`/`DATABASE.md`/`DEPLOYMENT.md`/
      `OBSERVABILITY.md`) at bootstrap when the PRD/PTR describe no such
      surface. GATE 1, GATE 2, VALIDATE, and the full content of both review
      checklists are preserved unconditionally — only dispatch count and
      doc-file count become complexity-aware.
  (C) Remove hard gates on trivial tasks the way FORGE's "qualify" step
      substitutes for a real review pipeline — rejected outright: the user's
      explicit constraint was "don't change our architecture," and this repo's
      own five invariants (VALIDATE/REVIEW/SECURITY/GATE1/GATE2) are exactly
      what (C) would weaken.
- Decision: (B). Combined `reviewer`+`security` dispatch runs as the
  **`security` persona (opus)**, instructed to also `Read` `reviewer.md` and
  apply its checklist as a second **Quality Findings** section — a deliberate
  choice over the cheaper alternative (running it as `reviewer`/sonnet), made
  explicitly with the human: preserves the higher-stakes judgment-heavy model
  tier for the security check while still halving dispatch count for
  trivial/small tasks. `medium`/`large` keep both dispatches and both models
  exactly as before. The `trivial`-eligibility checklist is a hard, literal
  5-condition test, not a vibe judgment, specifically so GATE 1 — now the
  *only* independent check for an inline plan, since there is no planner to
  disagree first — has an unambiguous thing to verify. An explicit escape
  hatch (BUILD discovers real complexity → stop, discard the inline plan,
  real `planner` dispatch, fresh GATE 1) prevents a misjudged inline plan from
  being patched in place and pushed through its original approval.
- Consequences: `loop.json` gains `plan_source` (`inline`/`planner`) and
  `review_dispatch` (`combined`/`separate`) fields, seeded `null` in all three
  places that create fresh state (`bin/cli.js`, `scripts/install.sh`,
  `/bootstrap` scaffold). `docs/SESSION.md` no longer updates on every
  COMMIT — only at `/handoff` — which is independently correct regardless of
  tier, not just a `fast`-tier optimization. Bootstrap on `fast` tier now
  creates fewer files, not just thinner ones, for surfaces a project doesn't
  have. The one real trade-off worth re-litigating if it proves wrong: GATE 1
  no longer has a second independent agent's take to compare against for a
  `trivial` task, so a misjudged eligibility checklist relies on the human
  gate alone to catch it — if that proves too thin in practice, tightening the
  checklist (or reverting to always dispatching `planner`) is a small,
  contained change, not a redesign.

## Decision 007: Shared-framework distribution model (`.master/`-only project footprint)
- Date: 2026-07-19
- Status: accepted — supersedes Decision 000's "fully self-contained, no external
  dependency" framing for what an *installed project* looks like
- Context: every install path (`--global`, `--local`, and the `master` plugin
  from Decision 005) was duplicating the full framework — `scripts/`, `docs/`,
  `.claude/hooks/`, `CLAUDE.md`, `MASTER-PROMPT.md` — into every consumer
  project. Direct inspection of `SanthoshVishnuRajamanickam/forge-framework`
  (cloned and read in full, not inferred from docs) showed the working
  alternative: source files hardcode a placeholder path in their prose; the
  installer performs a literal text substitution at copy time, rewriting that
  placeholder to wherever the framework actually landed (`~/.claude/`, a
  custom config dir, or `./.claude/`); the framework bundle itself is copied
  once into a `.claude/<framework-name>/` subfolder (already inside the
  config directory Claude Code users expect, not visible top-level clutter);
  and project-specific state (`.forge/PROJECT.md`/`STATE.md`/`ROADMAP.md`) is
  created later by an init command, not by the installer. The user explicitly
  requested this exact model, having independently identified and reported a
  real bug this design also fixes in passing: `.github/workflows` (this
  repo's own CI) was leaking into every `--local` install.
- Options considered:
  (A) Leave the full per-project copy as-is — matches Decision 000's original
      wording literally, but every project keeps duplicating the entire
      framework, contradicts the user's explicit "I don't want its source
      code inside my project" requirement, and doesn't fix the confirmed
      `.github/workflows` leak (a symptom of the same root cause: nothing
      distinguished "framework" files from "project" files in the copy list).
  (B) Shared-framework model: the framework (agents, commands, skills,
      scripts, hooks, reference docs, `CLAUDE.md.starter`, `MASTER-PROMPT.md`)
      lives once, at `<config-dir>/claude-master-setup/` for npm installs or
      the plugin's own cache for the plugin path — never duplicated. A
      project gets only `.master/` (state + its own docs) and `CLAUDE.md`.
      `${CLAUDE_PLUGIN_ROOT}` is the one literal token every agent/command
      source file uses for framework-reference paths; the plugin path
      resolves it natively, and `bin/cli.js` performs the identical text
      substitution itself at copy time for the two npm paths (mirroring
      FORGE's mechanism exactly, confirmed against its real source).
  (C) A per-project private framework cache (e.g. `./.master/framework/`)
      instead of one shared machine-wide location — rejected: recreates the
      exact duplication problem this Decision exists to remove, just moved one
      level down.
- Decision: (B). Concretely:
  - **11 scripts** switched their project-root resolution from
    `cd "$(dirname "$0")/.."` (assumes colocation with the project) to
    `${CLAUDE_PROJECT_DIR:-$PWD}` — verified this actually works, not just
    assumed, by invoking the shared-location copy of `validate.sh` and
    `loop-event.sh` against a separate sandboxed project directory and
    confirming they operated on that project, not on themselves. Two
    explicit exceptions, not covered by the uniform fix: `select-skills.sh`
    (its `REPO_ROOT` only ever located a sibling framework script, fixed to
    `SCRIPT_DIR` instead) and `self-check.sh`/`install.sh` (these check the
    *harness source repo's own* file inventory for `package.json`'s
    `test`/`prepack` and this repo's own CI — never meant to run against a
    consumer project, left untouched).
  - **5 hooks**: bodies already used `$CLAUDE_PROJECT_DIR` internally (3 of
    5) or had no location dependency (2 of 5) — confirmed via direct
    inspection, no hook logic changes needed. `.claude-plugin/plugin.json`
    gained a `hooks` block (`${CLAUDE_PLUGIN_ROOT}`-based) and
    `bin/cli.js`'s `mergeFrameworkSettings` gained an equivalent
    `$HARNESS_FRAMEWORK_ROOT`-based block for the npm paths — completing
    what Decision 005 explicitly deferred ("option B"), since both reasons for
    deferring it (double-firing risk with a `--local` scaffold that also
    copied hooks; hooks needing per-project `.claude/state/`) no longer
    apply once state lives in `.master/state/` and `--local` stops copying
    hook files into the project.
  - **This repo's own source stays exactly as it is today** — full
    `scripts/`/`docs/`/`.claude/` visible, unmigrated. It is the origin the
    framework bundle gets copied *from*, not a consumer of it; `.master/`
    applies only to projects built *with* the harness. `git clone` +
    `scripts/install.sh` is repositioned as a harness-*development* path
    (forking/extending the harness itself), not a recommended way to start a
    new product — cloning the whole framework repo into your own project is
    exactly the duplication this Decision removes.
  - New assets required and created: `templates/master-docs/*.md` (10
    starter project-doc stubs — 4 reused verbatim from this repo's own
    already-blank templates; 6 newly written) and
    `templates/CLAUDE.md.starter` (this repo's own `CLAUDE.md`, adapted:
    "What this repository is" reframed as "what this *project* is, built
    with the harness" rather than describing the harness itself).
- Consequences: `npx claude-master-setup --local` no longer requires a
  separate `--global` run — it calls the same idempotent
  `ensureFrameworkInstalled()` first, so the shared framework materializes
  transparently on first use either way. An npm-path project has **no**
  project-level `.claude/` folder at all; agents/commands/hooks are 100%
  user-scope (per-project overrides remain possible by hand via
  `./.claude/settings.local.json`, just not scaffolded by default). Running
  *both* the npm package globally and the `master` plugin on the same
  machine double-fires hooks (Claude Code doesn't dedupe hooks from two
  sources) — documented as a known limitation, the two paths are meant to be
  mutually exclusive per machine, not a bug to silently paper over. One
  follow-up deliberately left open rather than rushed: the `Bash(bash
  scripts/:*)`-style tool-permission allowlist patterns in
  `.claude/settings.json` and several agent/command frontmatter blocks are
  literal-prefix matches that won't match the new absolute-path script
  invocations; broadening them needs its own explicit, scoped decision
  (flagged to the human, not silently widened) rather than folding it into
  this already-large change.

- Later update (2026-07-19): lean command surface — `/bootstrap` scaffolds
  `.master/`; `/pause` and `/decide` added; `/init` and `/ship` deleted from
  `.claude/commands/`.
