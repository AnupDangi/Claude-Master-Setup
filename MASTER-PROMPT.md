# Bootstrap Prompt (v4) — Decision 007

Bootstrap playbook for `/master:bootstrap` (plugin) or `/bootstrap` (npm).
**Not a slash command.** Do **not** implement feature code here.

You act as a senior architect: challenge the design, size the work to the
build-effort tier, and leave a foundation the loop can run from disk alone.

---

## Prerequisite

`.master/` must already exist (`.master/docs/PROJECT_STATE.md` present).
If missing, `/master:bootstrap` will scaffold `.master/` automatically — or create it first, then continue.

**Write only:**

- `CLAUDE.md` (stable conventions)
- `.master/docs/*` (project memory — tier-scaled)
- `.master/state/` updates via scripts (build effort / loop fields)

**Never:**

- Create a top-level app `docs/` tree for harness memory
- Copy framework agents/commands/hooks/scripts into the project
- Generate project-local `.claude/agents`, `.claude/commands`, or `.claude/hooks`
- Begin feature implementation

The harness framework lives **once** at `${CLAUDE_PLUGIN_ROOT}` (plugin) or the
shared npm install — not inside the app repo.

---

## Phase 0 — Measure build effort

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/estimate-build-effort.sh --write
# optional: … PRD.md PTR.md "one-line intent"
```

Read `.master/state/build_effort.json` and `${CLAUDE_PLUGIN_ROOT}/docs/BUILD_EFFORT.md`.

| Tier | What to write under `.master/docs/` |
|---|---|
| **fast** | Thin ARCHITECTURE + short ROADMAP (2–4 outcomes) + PROJECT_STATE; skip unused surface docs (`API` / `DATABASE` / `DEPLOYMENT` / `OBSERVABILITY`) |
| **standard** | Core set + ROADMAP 3–6 |
| **rigorous** | Full core + Decisions; phased ROADMAP with risks |

**Every tier still gets:** VALIDATE + REVIEW + SECURITY + GATE 1/2 on every later `/loop` iteration. Speed ≠ skipping gates.

Override: `HARNESS_BUILD_EFFORT_TIER=fast|standard|rigorous`. Confirm with the human if the estimate looks wrong.

---

## Phase 1 — Understand

Read `PRD.md` and `PTR.md` completely (greenfield). Extract vision, personas,
requirements, constraints, scale, security, deployment, AI/ML needs, success
criteria. **Never invent missing facts** — ask.

Brownfield (thin/missing PRD/PTR): follow `${CLAUDE_PLUGIN_ROOT}/docs/BROWNFIELD.md`
first, then continue here.

---

## Phase 2 — Clarify

Challenge architecture and stack choices (scale, security, ops, cost, DX,
extensibility). List gaps, contradictions, risks. **Stop and ask** until
ambiguity that would block foundation is resolved.

---

## Phase 3 — Design

Prefer the simplest design that meets stated scale. Define only what this
project needs: boundaries, data flow, API/DB (if any), auth, testing,
deployment, workflow. Depth matches the build-effort tier — do not gold-plate
a `fast` app.

Delegate significant decisions to the **architect** subagent; record Decisions in
`.master/docs/DECISIONS.md`.

---

## Phase 4 — Write foundation (`.master/docs/` only)

Fill or refine stubs under `.master/docs/` (scaffolded by `/master:bootstrap` from
`templates/master-docs/`). **Overwrite stubs with real content; do not recreate
the framework.**

**Always (all tiers):**

```text
.master/docs/
├── ARCHITECTURE.md
├── PROJECT_STATE.md
├── ROADMAP.md          # outcome-sized shippable units for /master:loop
├── DECISIONS.md
├── CODING_STANDARDS.md
├── SECURITY.md
├── TESTING.md
├── SESSION.md
├── HANDOFF.md
└── CHANGELOG.md
```

**Add only if the PRD/PTR actually need them** (especially skip on `fast`):

`API.md`, `DATABASE.md`, `DEPLOYMENT.md`, `OBSERVABILITY.md`,
`DEVELOPMENT_WORKFLOW.md`, `CONTRIBUTING.md`.

Roadmap rules: few outcomes — fast 2–4, standard 3–6, rigorous phased. Never
15+ micro-tasks. Optional `(depends: …)` annotations per
`${CLAUDE_PLUGIN_ROOT}/docs/LOOP.md`.

Wire validation by ensuring the stack is detectable for
`${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh` (tests/lint/build) — do not copy
`validate.sh` into the project.

---

## Phase 5 — CLAUDE.md

Write or update root `CLAUDE.md` with **stable** knowledge only: mission, stack,
conventions, DoR/DoD, security principles, working instructions.

Point current-state readers at `.master/docs/` (not a top-level `docs/`).

Do **not** put sprint status, TODOs, or the feature backlog in `CLAUDE.md` —
those live in `.master/docs/PROJECT_STATE.md` / `ROADMAP.md` / `CHANGELOG.md`.

Use `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.starter` as the shape if creating
fresh.

---

## Phase 6 — Memory layers

```text
PRD.md / PTR.md
      ↓
CLAUDE.md                 # stable
      ↓
.master/docs/             # shared project memory (committed)
.master/state/            # loop machine state (gitignored)
      ↓
Claude Code auto-memory   # worktree-local; promote durable facts into .master/docs/
```

Do not duplicate the same fact across layers.

---

## Phase 7 — Stop for approval

Before any feature work, the human should have:

1. Confirmed build-effort tier  
2. Architecture / tech / risk notes (depth by tier)  
3. `CLAUDE.md`  
4. Tier-appropriate `.master/docs/` (especially ROADMAP + PROJECT_STATE)  
5. At least one Decision when a non-trivial decision was made  

**Do not implement product code until they approve.**

Then: `/master:loop` (plugin) or `/loop` (npm). Spec:
`${CLAUDE_PLUGIN_ROOT}/docs/LOOP.md`. External tools: `/master:mcp-add` /
`/mcp-add`.

Future sessions read, in order:

1. `CLAUDE.md`  
2. `.master/docs/PROJECT_STATE.md`  
3. `.master/docs/SESSION.md`  
4. `.master/docs/DECISIONS.md`  
5. `.master/state/loop.json`  

---

## References (do not restate)

- `${CLAUDE_PLUGIN_ROOT}/docs/BUILD_EFFORT.md`
- `${CLAUDE_PLUGIN_ROOT}/docs/LOOP.md`
- `${CLAUDE_PLUGIN_ROOT}/docs/BROWNFIELD.md`
- `${CLAUDE_PLUGIN_ROOT}/docs/AGENTS.md`
- `${CLAUDE_PLUGIN_ROOT}/docs/AI_OS.md`
