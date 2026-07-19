# Changelog

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
