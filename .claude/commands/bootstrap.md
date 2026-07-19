---
description: Start a project — scaffold .master if needed, then engineering foundation from PRD/PTR (no feature code)
allowed-tools: Read, Grep, Glob, Task, Write, Edit, Bash(test:*), Bash(mkdir:*), Bash(cp:*), Bash(git:*), Bash(bash scripts/:*), Bash(./scripts/:*), Bash(bash */scripts/*.sh:*)
model: opus
---
# Bootstrap the Project

Requirements present:
- Master: !`test -f .master/docs/PROJECT_STATE.md && echo "OK — .master present" || echo "will scaffold .master first"`
- PRD: !`test -f PRD.md && echo "PRD.md found" || echo "PRD.md MISSING"`
- PTR: !`test -f PTR.md && echo "PTR.md found" || echo "PTR.md MISSING"`
- Stack detect: !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh 2>/dev/null || echo "detect-stack unavailable"`

## 0. Scaffold `.master/` if missing

If `.master/docs/PROJECT_STATE.md` is **missing**, create the scaffold now (same
(do not ask the human to run a second command):

1. Create `.master/state/` and full `.master/state/loop.json` (phase `idle`,
   validate retries, complexity fields — merge defaults if a partial file exists).
2. Copy stubs from `${CLAUDE_PLUGIN_ROOT}/templates/master-docs/` into
   `.master/docs/` (skip existing files).
3. Create `./CLAUDE.md` from `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.starter`
   only if missing.
4. Ensure `.gitignore` has `.env`, `.env.*`, and `.master/state/` (do not create `.env` files).

If already scaffolded, skip this section.

## 1. Measure build effort

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/estimate-build-effort.sh --write`
(optionally pass user intent as arg 3). Read `${CLAUDE_PLUGIN_ROOT}/docs/BUILD_EFFORT.md`.

| Tier | Bootstrap docs | After bootstrap |
|---|---|---|
| **fast** | Thin CLAUDE.md + short ROADMAP (2–4) + thin ARCHITECTURE; skip unused surface docs | Outcome-first |
| **standard** | Core docs; ROADMAP 3–6 | Normal loop |
| **rigorous** | Full docs + Decisions; phased ROADMAP | Full rigor |

**Invariants:** later `/master:loop` iterations still run VALIDATE + REVIEW + SECURITY and GATE 1/2.

## 2. Mode selection

**Greenfield** — `PRD.md` + `PTR.md` present. Follow
`${CLAUDE_PLUGIN_ROOT}/MASTER-PROMPT.md` **(v4)** end to end. Output only
`.master/docs/` + `CLAUDE.md`.

**Brownfield** — existing code, thin/missing PRD/PTR. Follow
[`BROWNFIELD.md`](${CLAUDE_PLUGIN_ROOT}/docs/BROWNFIELD.md), then the same
foundation under `.master/docs/`.

## 3. Both modes

Delegate **architect** for significant choices; record **Decisions** in
`.master/docs/DECISIONS.md`. Core docs always under `.master/docs/`:
ARCHITECTURE, ROADMAP, PROJECT_STATE, DECISIONS, CODING_STANDARDS, TESTING,
SECURITY.

**Do not write feature code.** Stop for human approval, then `/master:loop`.
If confused mid-bootstrap, `/master:pause` and ask numbered questions.
