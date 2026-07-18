---
description: Bootstrap greenfield (PRD/PTR) or brownfield (existing codebase) engineering foundation — no feature code
allowed-tools: Read, Grep, Glob, Task, Write, Edit, Bash(bash scripts/:*)
model: opus
---

# Bootstrap the Project

Requirements present:
- PRD: !`test -f PRD.md && echo "PRD.md found" || echo "PRD.md MISSING"`
- PTR: !`test -f PTR.md && echo "PTR.md found" || echo "PTR.md MISSING"`
- Stack detect: !`bash scripts/detect-stack.sh 2>/dev/null || echo "detect-stack unavailable"`
- Build effort: !`bash scripts/estimate-build-effort.sh --write 2>/dev/null | head -c 2000 || echo "estimate unavailable"`

## 0. Measure build effort (required first)

Run `bash scripts/estimate-build-effort.sh --write` (optionally pass user intent as
arg 3). Read `docs/BUILD_EFFORT.md`. Persist tier into `.claude/state/`.

| Tier | Bootstrap docs | After bootstrap |
|---|---|---|
| **fast** | Thin — CLAUDE.md + short outcome ROADMAP (2–4) + thin ARCHITECTURE | Focus on user outcomes; less markdown scaffolding |
| **standard** | Normal docs set; ROADMAP 3–6 | Normal loop |
| **rigorous** | Full docs + ADRs; careful multi-phase ROADMAP | Full harness rigor |

**Invariants for every tier:** VALIDATE + REVIEW + SECURITY every iteration; never
skip GATE 1/2. Speed ≠ skipping quality. See `docs/BUILD_EFFORT.md`.

## Mode selection

**Greenfield** — `PRD.md` + `PTR.md` present (or user will supply them). Follow
`MASTER-PROMPT.md` end to end using those as the source of truth, **scaled by
build-effort tier**.

**Brownfield** — codebase already exists (manifests / `src` / git history) and
PRD/PTR are missing or thin. Follow [`docs/BROWNFIELD.md`](../../docs/BROWNFIELD.md):

1. Run `bash scripts/detect-stack.sh` and inventory the tree (read-only).
2. Ask clarifying questions (mission, invariants, quality bar).
3. Draft `PRD.md`/`PTR.md` from observed reality + human confirmation.
4. Re-run `estimate-build-effort.sh --write`.
5. Delegate to **architect** for ADRs documenting *current* architecture (depth by tier).
6. Generate docs + `docs/ROADMAP.md` sized to tier.
7. **Do not rewrite the stack or write feature code.**

## Both modes

Delegate to the **architect** subagent for architecture review / technology
validation (and effort-tier confirmation), then generate CLAUDE.md sections and
docs **matching `docs_profile`**.

**Roadmap sizing:** Prefer few shippable **outcomes**. Fast: 2–4. Standard: 3–6.
Rigorous: phased milestones with explicit risks. Never 15+ micro-tasks.

**Do not write implementation code** during bootstrap (even on `fast`). After the
human approves the foundation, `/loop` may be outcome-first on `fast` tiers.
Ask clarifying questions on anything ambiguous and stop for approval before
finishing.
