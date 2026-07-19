---
description: Bootstrap greenfield (PRD/PTR) or brownfield (existing codebase) engineering foundation — no feature code
allowed-tools: Read, Grep, Glob, Task, Write, Edit, Bash(bash scripts/:*), Bash(./scripts/:*), Bash(bash */scripts/*.sh:*)
model: opus
---
# Bootstrap the Project

**Prerequisite:** `.master/` must already be scaffolded. If
`.master/docs/PROJECT_STATE.md` is missing, stop and tell the human to run
`/master:init` first — do not invent a partial scaffold.

Requirements present:
- Init: !`test -f .master/docs/PROJECT_STATE.md && echo "OK — .master scaffolded" || echo "MISSING — run /master:init first"`
- PRD: !`test -f PRD.md && echo "PRD.md found" || echo "PRD.md MISSING"`
- PTR: !`test -f PTR.md && echo "PTR.md found" || echo "PTR.md MISSING"`
- Stack detect: !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh 2>/dev/null || echo "detect-stack unavailable"`

## 0. Gate on init

If `.master/docs/PROJECT_STATE.md` is missing, **stop**. Do not run
`estimate-build-effort.sh --write` yet (that would create state without starter docs).

## 1. Measure build effort

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/estimate-build-effort.sh --write`
(optionally pass user intent as arg 3). Read `${CLAUDE_PLUGIN_ROOT}/docs/BUILD_EFFORT.md`.
Persist tier into `.master/state/` (full `loop.json` defaults are merged by the script).

| Tier | Bootstrap docs | After bootstrap |
|---|---|---|
| **fast** | Thin — CLAUDE.md + short outcome ROADMAP (2–4) + thin ARCHITECTURE; **skip creating** any surface doc (`API.md`/`DATABASE.md`/`DEPLOYMENT.md`/`OBSERVABILITY.md`) whose surface the PRD/PTR don't describe | Focus on user outcomes; less markdown scaffolding |
| **standard** | Normal docs set; ROADMAP 3–6 | Normal loop |
| **rigorous** | Full docs + ADRs; careful multi-phase ROADMAP | Full harness rigor |

**Invariants for every tier:** VALIDATE + REVIEW + SECURITY every iteration; never
skip GATE 1/2. Speed ≠ skipping quality. See `${CLAUDE_PLUGIN_ROOT}/docs/BUILD_EFFORT.md`.

## Mode selection

**Greenfield** — `PRD.md` + `PTR.md` present (or user will supply them). Follow
`${CLAUDE_PLUGIN_ROOT}/MASTER-PROMPT.md` end to end using those as the source of truth, **scaled by
build-effort tier**. Write project docs under `.master/docs/` (never a top-level `docs/` tree for app memory).

**Brownfield** — codebase already exists (manifests / `src` / git history) and
PRD/PTR are missing or thin. Follow [`BROWNFIELD.md`](${CLAUDE_PLUGIN_ROOT}/docs/BROWNFIELD.md):

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh` and inventory the tree (read-only).
2. Ask clarifying questions (mission, invariants, quality bar).
3. Draft `PRD.md`/`PTR.md` from observed reality + human confirmation.
4. Re-run `estimate-build-effort.sh --write`.
5. Delegate to **architect** for ADRs documenting *current* architecture (depth by tier).
6. Generate docs + `.master/docs/ROADMAP.md` sized to tier.
7. **Do not rewrite the stack or write feature code.**

## Both modes

Delegate to the **architect** subagent for architecture review / technology
validation (and effort-tier confirmation), then generate CLAUDE.md sections and
docs **matching `docs_profile`** under `.master/docs/`. On `docs_profile: thin`, this means *creating
fewer files*, not just shorter ones: skip a surface doc entirely (`API.md`,
`DATABASE.md`, `DEPLOYMENT.md`, `OBSERVABILITY.md`) when the project has no
such surface, per `${CLAUDE_PLUGIN_ROOT}/docs/BUILD_EFFORT.md`'s fast-tier bullet. Core docs
(`ARCHITECTURE.md`, `ROADMAP.md`, `PROJECT_STATE.md`, `DECISIONS.md`,
`CODING_STANDARDS.md`, `TESTING.md`, `SECURITY.md`) are always created under `.master/docs/`.

**Roadmap sizing:** Prefer few shippable **outcomes**. Fast: 2–4. Standard: 3–6.
Rigorous: phased milestones with explicit risks. Never 15+ micro-tasks.

**Do not write implementation code** during bootstrap (even on `fast`). After the
human approves the foundation, `/master:loop` may be outcome-first on `fast` tiers.
Ask clarifying questions on anything ambiguous and stop for approval before
finishing.
