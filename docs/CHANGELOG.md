# Changelog

## 0.9.1 — JSONL loop events + /status honesty summary

- New `scripts/append-loop-event.py`: appends structured JSONL records to
  `.master/state/history/events.jsonl` (created on first use, never packaged).
  Event shape: `ts`, `type`, `iteration`, `mode`, `phase`, `agents`, `detail`.
- `setup-loop.sh` emits `loop_start`, `steer`, or `resume` event after each invocation.
- `require-agents-before-edit.sh` (Phase A hook) emits `edit_blocked` with
  `blocked_path` detail before denying product writes.
- `loop-stop-hook.sh` emits `loop_complete`, `paused`, `max_iterations`, or
  `loop_error` on terminal states; also emits `validation_green`/`validation_red`
  when validation status is known at stop time.
- `/status` command: reads last 10 lines of `events.jsonl`, shows ≤5 most recent
  events; agents honesty check flags delegated/parallel loops with empty
  `assigned_agents` as "gate will block product writes".
- `events.jsonl` lives under `.master/state/` (already gitignored); event logs
  are never packaged with the framework.
- `self-check.sh`: verifies script exists + Python syntax; after simulated setup
  confirms `loop_start` event written; after gate deny confirms `edit_blocked` event.

## 0.9.0 — Runtime truth gate + DESIGN enforcement

- `templates/project.json`: new optional `runtime_check` field (default `null`).
  When set to a non-null shell command string, `validate.sh` runs it as the final
  stage after all stack checks; a non-zero exit makes the entire gate RED.
  `null` leaves behavior identical to 0.8.x.
- `scripts/validate.sh`: reads `runtime_check` from `.master/project.json`; executes
  it as a named final `step` when non-null; skips silently when null or absent.
- `bootstrap.md`: added visual product gate rule — if UI/visual evidence is found,
  DESIGN.md **must** be created before bootstrap finishes; `runtime_check` set only
  when an obvious smoke command exists (else leave null).
- `loop.md` GATE section: added visual product gate — if UI task and
  `.master/docs/DESIGN.md` is missing, loop pauses and asks before entering BUILD;
  never silently enters BUILD for visual work without a DESIGN.md.
- `docs/SETUP.md` + `docs/LOOP.md`: documented `runtime_check` field and DESIGN gate.
- `self-check.sh`: Phase D assertions — template has `runtime_check` key; validate.sh
  contains the stage; `runtime_check: "false"` → RED; `runtime_check: null` → GREEN.

## 0.8.2 — Specialist contract depth

- Deepened agent specs to ~50–80 lines each with explicit: refuse conditions,
  inputs, constraints, anti-stall rules, failure→pause behavior, and return schema.
  Agents affected: implementer, implementer-opus, validator, reviewer, planner, orchestrator.
- Stop-hook Gate 2.5: delegated/parallel completion now requires project-root
  `AGENT_TASK.md` to exist and contain `## Objective`; missing or empty → loop paused.
- loop.md PLAN section: non-direct mode must write `AGENT_TASK.md` with `## Objective`,
  set `assigned_agents`, then spawn Task(s) — order is now explicit and stop-hook enforced.
- Self-check: agent files verified for `## Role`, return schema header, and anti-stall keyword.

## 0.8.1 — Signal-based classifier + routing policy

- `classify-task.py` rewritten with explicit signal sets (DIRECT/DELEGATED/PARALLEL)
  and a `routing_reason` field in every result.
- `setup-loop.sh` persists `routing_reason` into `loop.json` on new loops.
- `loop.md` (PLAN section): model may **downgrade** `execution_mode` only
  (parallel→delegated→direct); upgrading requires planner and `routing_reason` update.
- `/status` output now shows `execution_mode` and `routing_reason` from loop state.
- `self-check.sh` extended with delegated `routing_reason` non-empty check,
  parallel classifier case, and `routing_reason` key presence assertion.
- `docs/LOOP.md` documents the downgrade-only rule and `routing_reason` field.


## 0.8.0 — Hard mid-loop Write/Edit gate

- PreToolUse `require-agents-before-edit`: active delegated/parallel loops with empty
  `assigned_agents` cannot Write/Edit product files until a Task is spawned.
- Prep allowlist: `.master/state/loop.json`, `AGENT_TASK.md`, `.master/docs/DESIGN.md`,
  `.master/docs/DECISIONS.md`. Direct/inactive/unclassified loops are unaffected.
- Wired after `protect-paths` in settings, plugin, and npm installer hook block.


## 0.7.2 — Prompt rewrite (session memory)

- Rewrote commands/agents for Role + Done-when + output schemas.
- Loop treats `loop.json` / handoff as durable session memory (not chat).
- Fixed validator tools so it can write `validation.*` into loop.json.
- Clarified direct-mode validation vs validator Task; reviewer is read-only.
- Hard REVIEW triggers; iteration_budget wording aligned across prompts.
- AGENT_TASK includes anti-stall + filled example.

## 0.7.1 — Highest-ROI hardening

- Allowlist skill names validated against checked-in `skills-list-snapshot.json`.
- `/loop` defaults `max_iterations` from `.master/project.json` `iteration_budget`.
- Installer warns when npm framework and `master` plugin are both active.
- Golden-loop CI smoke: setup → GREEN validate → stop-hook completion + handoff.

## 0.7.0 — Default skills via npx skills + runtime ensure

- Installer auto-installs curated `vercel-labs/agent-skills` into `~/.claude/skills`
  via `npx skills` (allowlist in `templates/skills-allowlist.json`).
- Runtime: `install-skill.sh` + `ensure-skills.sh` install allowlisted gaps during
  `/loop` setup (and optionally `/bootstrap`); outside-allowlist sources are
  suggested to the user, not auto-installed.
- Skill install is best-effort: network/CLI failures warn; harness install continues.
- Claude plugins remain hints-only (not auto-installed).
- Skill discovery also scans project `.agents/skills/` and uses allowlist catalog
  keyword boosts when ranking ≤3 skills for `/loop`.

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
