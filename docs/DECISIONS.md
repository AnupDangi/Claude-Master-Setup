# Architectural Decisions (ADRs)

> Append-only. One entry per significant decision. The architect writes these; never
> silently reverse one — supersede it with a new ADR that references the old.

## ADR template
```
## ADR-NNN: <short title>
- Date: YYYY-MM-DD
- Status: proposed | accepted | superseded by ADR-XXX
- Context: what forced a decision (constraints, scale, requirements)
- Options considered: A / B / C — with the key trade-off of each
- Decision: what we chose
- Consequences: what this makes easy, what it makes hard, what we accept
```

---

## ADR-000: Adopt the self-contained loop harness
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

## ADR-001: Reposition as an autonomous software engineering harness; roll out docs-first
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
  for the Marketplace stage the vision proposes without re-litigating ADR-000 (the
  self-contained-by-default decision) — Marketplace stays an optional, deferred
  growth-path stage, not a redesign of the default install. The Scheduler,
  Evaluation runner, Benchmarks, and Templates library remain unbuilt; they are
  tracked in `docs/ROADMAP.md` and must each land as their own validated
  iteration, per this harness's own rules.

## ADR-002: Build dynamic model routing on explicit user direction, not internally-gathered evidence
- Date: 2026-07-18
- Status: accepted
- Context: `docs/MODEL_ROUTING.md` and ADR-001's Milestone 1 item deferred dynamic
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

## ADR-003: Capability-driven orchestration via local skills, hierarchical subagents, and worktree fan-out
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

## ADR-004: Build-effort value function (fast vs rigorous harness dial)
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

## ADR-004: Build-effort value function (fast vs rigorous harness dial)
- Date: 2026-07-19
- Status: accepted
- Context: Generic builds (CLI, todo, typical ecommerce, API wrappers) were paying
  full markdown-scaffold cost; complex builds (game clones, train+ship LLMs) need
  full multi-phase rigor. Users need a **project-level** dial based on their
  PRD/PTR/intent, separate from per-task `task_complexity`.
- Options considered:
  (A) Always full docs — safe but slow for known patterns.
  (B) Always thin docs — fast but risky for complex/novel systems.
  (C) Estimator value function → `fast|standard|rigorous` with invariants that
      VALIDATE + REVIEW + SECURITY never turn off.
- Decision: (C). `scripts/estimate-build-effort.sh` + `docs/BUILD_EFFORT.md`;
  bootstrap runs `--write`; human override via `HARNESS_BUILD_EFFORT_TIER`.
- Consequences: Faster outcome delivery on generic work; clearer expectations on
  hard work. Heuristic scores can misclassify — override required. Agents must not
  interpret `fast` as permission to skip gates.
