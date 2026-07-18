# Project State

> The first file a new session reads after `CLAUDE.md`. Updated by `docs-writer`
> after every loop iteration. Current state only — no history (that's CHANGELOG).

## Status
Harness is an autonomous software engineering / **AI OS** layer on Claude Code
(ADR-001/003). Milestones 0–2 (objective eval), 4 (capability orchestration),
and **5 (AI OS control plane)** are complete: event log, scorecard→SELECT,
harness CI, hard path blocking, budget stop, leases, brownfield bootstrap,
build-effort value function (ADR-004: `fast|standard|rigorous`).
Milestone 3 (benchmarks/plugin packaging) remains deferred. 11 agents, 10
commands, skill `capability-orchestrator`. npm package **v0.4.0** is publish-ready:
self-check, prepack, manual tarball allowlist/secret inspection, clean install,
local scaffold, CLI help, and `npm publish --dry-run` are GREEN. npm
authentication is active;
the real publish remains an explicit human action.

## Done
- Engineered loop with two human gates; hard validation; reviewer + security
  every iteration; retry cap and one-COMMIT default budget.
- Eleven specialist agents, ten commands, task graphs, dependency-aware SELECT,
  model routing (`implementer` / `implementer-opus`), and MCP scout.
- Capability orchestration (ADR-003): local skill discovery, hierarchical caps,
  AGENT_TASK contract, and guarded worktree fan-out.
- AI OS control plane: persistent events, scorecard→SELECT, budget stop, leases,
  harness CI, hard protected-path hooks, and brownfield bootstrap.
- Build-effort dial (ADR-004): `fast|standard|rigorous` from PRD/PTR; review and
  security remain mandatory on all tiers.
- User-level-only statusline; project name/git resolve from project root.
- npm package v0.4.0 metadata, allowlisted files, MIT license, zero dependencies.

## In progress
- None. Branch `v2-os` is ready for final push/tag/publish approval.

## Next up
1. Push `v2-os`, tag `v0.4.0`, and publish v0.4.0 when approved.
2. Later: full Scheduler, benchmark suite, subjective evaluation, optional
   plugin marketplace packaging.

## Known issues / risks
- Permission allowlists and hooks are defense-in-depth, not a same-user sandbox;
  use a VM for untrusted prompts (`docs/SECURITY.md`).
- Budget, leases, and event history are cooperative local controls, not
  cryptographic enforcement.
- Full Scheduler, benchmarks, subjective metrics, and plugin packaging remain
  explicitly unimplemented.

## Blocked / needs human
- Approval for external `git push`, release tag, and `npm publish`.
