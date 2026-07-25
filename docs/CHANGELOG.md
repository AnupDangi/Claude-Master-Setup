# Changelog

## 1.0.2 — Install harden: single path + hook dedupe

- Wider hook merge: strip legacy Master hooks by `harness:` id, `$CLAUDE_MASTER_ROOT` /
  `$HARNESS_FRAMEWORK_ROOT`, and known script paths (stops 4× hook accumulation).
- Install/`--repair` enforces single path: keeps npm framework, disables
  `master@claude-master-setup` when both are active; drops `HARNESS_FRAMEWORK_ROOT`.
- New CLI: `--doctor` (health check) and `--repair` (dedupe + restore).
- Ship-install tests re-install + repair; self-check asserts doctor/repair help.


## 1.0.1 — README diagrams for npm

- Pre-render Mermaid as PNGs (`docs/*.mmd` → `docs/*.png`) so npm README shows diagrams
  (npm does not execute Mermaid; GitHub does).
- README uses absolute `raw.githubusercontent.com` image URLs linked to `.mmd` sources.
- `npm run docs:diagrams` / `prepublishOnly` via `scripts/render-diagrams.sh`.

## 1.0.0 — Stable product release

First **stable** npm cut after `0.6.3`. Unreleased internal milestones **0.7.0–0.9.2**
are included here (not published separately).

### Highlights

- Fail-closed Write/Edit gate for delegated/parallel until `assigned_agents` is set
- Signal-based routing with `routing_reason` and downgrade-only policy
- Deeper specialist contracts + `AGENT_TASK.md` completion gate
- Optional `runtime_check` + DESIGN.md gate for UI work
- JSONL loop events + `/status` honesty summary
- Docs **generated from evidence** (no template copy into projects)
- Curated skills install via `npx skills` + runtime `ensure-skills`
- Product README with architecture diagrams and missing-setup checklist

### From unreleased 0.7–0.9 (summary)

- Skills allowlist, iteration_budget defaults, dual-install warning, golden-loop CI
- Prompt rewrite for session memory (JSON + handoff, not chat)
- PreToolUse `require-agents-before-edit`, classifier rewrite, agent depth
- `runtime_check`, DESIGN enforcement, `append-loop-event.py` in framework ship path

## 0.6.3 — Phased loop steer + progressive docs

- Enforced phased pipeline: GATE→PLAN→BUILD→VALIDATE→REVIEW→SHIP→COMPLETE.
- Steer/resume resets validation state (and re-arms `validation-pending`).
- Agent enforcement: validator records `validation.agent`; reviewer pass for important/security-sensitive changes.
- Progressive docs via `sync-project-docs.sh` at SHIP (existing/production maturity).
- Installer ships `sync-project-docs.sh` as part of framework runtime scripts.

## 0.6.2 — README architecture + statusline restore

- Restored user-level `~/.claude/statusline.sh` install and settings wiring via `npx`/`bin/cli.js`.
- Expanded README architecture: full loop, skill ecosystem, shared vs project state.
- Smoke tests verify statusline is installed and renders the project name.

## 0.6.1 — CI for adaptive loop

- Rewrote GitHub Actions for the 0.6 surface (removed deleted AI-OS script steps).
- Made self-check stale-reference scanning portable (no ripgrep dependency on CI).

## 0.6.0 — Adaptive loop cleanup

- Replaced Markdown loop state with structured JSON and a default two-iteration cap.
- Added exact completion + validation GREEN enforcement, cancellation, pause, compact
  continuation, and automatic structured handoff.
- Added direct/delegated/parallel routing, bounded local skill selection, and
  file-owned worktree fan-out capped at three writers.
- Made npm seed output project-specific from README/manifests/source/test evidence.
- Reduced commands to bootstrap, loop, cancel, status, pause, and handoff.
- Reduced specialists to architect, planner, orchestrator, implementers, validator,
  and a combined quality/security reviewer.
- Removed AI-OS/build-effort/event/lease/scorecard machinery, companion installation,
  statusline, dead commands, redundant docs/templates, and worktree artifacts.
- Tightened npm and installer allowlists; consumer installs contain no `.env`,
  `.github`, maintainer files, or framework prose in project `CLAUDE.md`.

## Earlier releases

Earlier 0.x releases established the plugin/npm installer, hooks, validation, and
worktree foundations. Their superseded governance workflow was removed in 0.6.0.

<details>
<summary>Internal unreleased notes (0.7–0.9) — folded into 1.0.0</summary>

### 0.9.2 — Generate docs on demand + ship append-loop-event

- Installer no longer copies `ROADMAP.md`; `.master/docs/` starts empty.
- Bootstrap generates evidence-backed docs; outlines only in `templates/master-docs`.
- `append-loop-event.py` added to `FRAMEWORK_SCRIPTS`.

### 0.9.1 — JSONL loop events + /status honesty

- `append-loop-event.py`, events from setup / Write gate / stop-hook; `/status` summary.

### 0.9.0 — Runtime truth + DESIGN enforcement

- `runtime_check` in project.json; DESIGN.md gate for UI at GATE.

### 0.8.2 — Specialist contract depth

- Deeper agent specs; AGENT_TASK.md required for delegated/parallel completion.

### 0.8.1 — Signal-based classifier + routing policy

- `routing_reason`; downgrade-only mode policy.

### 0.8.0 — Hard mid-loop Write/Edit gate

- `require-agents-before-edit` PreToolUse hook.

### 0.7.2 — Prompt rewrite (session memory)

- Role / Done-when / output schemas; JSON session memory.

### 0.7.1 — Highest-ROI hardening

- Allowlist snapshot check; iteration_budget; dual-install warn; golden-loop.

### 0.7.0 — Default skills via npx skills

- Curated allowlist install + runtime `ensure-skills.sh`.

</details>
