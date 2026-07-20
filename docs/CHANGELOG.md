# Changelog

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
