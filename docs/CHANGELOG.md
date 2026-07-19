# Changelog

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
