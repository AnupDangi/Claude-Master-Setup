# Build effort (project complexity dial)

> **Value function:** decide whether to *build faster* (generic / known patterns)
> or *build carefully* (novel, multi-phase, high-risk) — **based on the user's
> PRD/PTR / intent**, not on agent preference.

Companion to [`LOOP.md`](LOOP.md), [`AI_OS.md`](AI_OS.md). Distinct from per-task
`task_complexity` (`trivial|small|medium|large`), which only picks planner depth
and `implementer` vs `implementer-opus`.

## Why this exists

Many requests are patterns agents have built hundreds of times (CLI, todo app,
typical ecommerce, thin API wrapper). Over-scaffolding markdown for those burns
session budget without improving outcomes.

Other requests are genuinely hard (game-engine clone, train + productionize an
LLM, multi-tenant platform). Those need the **full harness** — phases, Decisions,
coarse careful roadmaps — so we do not ship risk under time pressure.

## Estimator

```bash
bash scripts/estimate-build-effort.sh              # PRD.md + PTR.md
bash scripts/estimate-build-effort.sh PRD.md PTR.md "build a todo cli"
bash scripts/estimate-build-effort.sh --write       # persist build_effort.json + loop.json fields
```

Override (human wins):

```bash
HARNESS_BUILD_EFFORT_TIER=fast|standard|rigorous
```

### Value function (summary)

```
score = 45
        − Σ(generic / known-pattern weights)
        + Σ(hard / novel / multi-phase weights)
        + structure bonuses (many phases, long spec, many integrations)
score ∈ [0, 100]
```

| Score | Tier | Docs profile | Build posture |
|---|---|---|---|
| `< 35` | **fast** | `thin` | Outcome-first; less markdown scaffolding |
| `35–64` | **standard** | `normal` | Default harness |
| `≥ 65` | **rigorous** | `full` | Full harness; more Decisions; careful phases |

### Example intents

| Intent | Expected tier |
|---|---|
| Simple CLI / todo app / call an API / typical ecommerce CRUD | **fast** |
| Mid-size product with auth + DB + a few integrations | **standard** |
| GTA Vice City clone / train+productionize LLM / publish multi-tenant SaaS | **rigorous** |

## What changes by tier

### fast
- Bootstrap: fill `CLAUDE.md` mission/stack, short `ROADMAP` (2–4 **user outcomes**), thin `ARCHITECTURE`, skip verbose template essays.
- Bootstrap surface docs: **do not create** a surface doc (`docs/API.md`,
  `docs/DATABASE.md`, `docs/DEPLOYMENT.md`, `docs/OBSERVABILITY.md`) at all
  when the PRD/PTR describe no such surface (e.g. no persistent datastore →
  skip `DATABASE.md`; no external API surface → skip `API.md`). A thin stub
  for a surface that doesn't exist is waste, not scaffolding — an absent file
  *is* the `thin` signal, not a filler file. If that surface appears later,
  `docs-writer`'s existing "surface docs — when that surface changed" rule
  creates it then. `TESTING.md`, `SECURITY.md`, and the core docs
  (`ARCHITECTURE.md`, `ROADMAP.md`, `PROJECT_STATE.md`, `DECISIONS.md`,
  `CODING_STANDARDS.md`) are always created — every project has code, tests,
  and decisions.
- After bootstrap: focus on implementing outcomes; docs-writer keeps `PROJECT_STATE`/`CHANGELOG` terse.
- Planner: short, outcome-tied plans; merge modules aggressively.

### standard
- Normal docs + 3–6 roadmap items; full AGENT_TASK plans.

### rigorous
- Full docs, early architect, Decisions for major decisions, multi-phase roadmap with explicit risks.
- Prefer correctness over speed; expect Task Graphs.

## Invariants (all tiers — non-negotiable)

These **never** turn off for “fast” builds:

1. **VALIDATE** — `scripts/validate.sh` hard gate (GREEN/RED).
2. **REVIEW** — `reviewer` every iteration before GATE 2.
3. **SECURITY** — `security` every iteration (light checklist OK on pure docs; full OWASP when auth, PII, network, payments, uploads, or secrets).
   (A `trivial`/`small` REVIEW may combine reviewer+security into one Task
   dispatch — see `docs/LOOP.md` §REVIEW — but both checklists still run in
   full every iteration; this is a dispatch-count optimization, not a
   weakening of invariants #2/#3.)
4. **GATE 1 / GATE 2** — human approvals; no auto-approve from “finish everything”.
5. **No `bypassPermissions`** as project default.

Speed comes from **less scaffolding and fewer roadmap micro-slices**, not from
skipping quality gates.

## State

Persisted when run with `--write`:

| Path | Fields |
|---|---|
| `.master/state/build_effort.json` | Full estimator output |
| `.master/state/loop.json` | `build_effort_tier`, `build_effort_score`, `docs_profile` |

Bootstrap and orchestrator **must** read this before sizing docs / SELECT posture.

## Human authority

If the estimator is wrong, set `HARNESS_BUILD_EFFORT_TIER` or ask the architect to
re-run with corrected intent. The human’s override always wins.
