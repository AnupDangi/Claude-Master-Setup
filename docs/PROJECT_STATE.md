# Project State

> The first file a new session reads after `CLAUDE.md`. Updated by `docs-writer`
> after every loop iteration. Current state only — no history (that's CHANGELOG).

## Status
Harness is an autonomous software engineering / **AI OS** layer on Claude Code
(ADR-001/003). Milestones 0–2 (objective eval), 4 (capability orchestration),
**5 (AI OS control plane)**, and the plugin-packaging slice of Milestone 3
(ADR-005) are complete: event log, scorecard→SELECT, harness CI, hard path
blocking, budget stop, leases, brownfield bootstrap, build-effort value
function (ADR-004: `fast|standard|rigorous`), and a `master` Claude Code
plugin giving namespaced `/master:*` commands. A complexity-aware ceremony
dial (ADR-006) now also cuts dispatch/doc-churn overhead on `trivial`/`small`
tasks without weakening any gate. Benchmarks / template library remain
deferred within Milestone 3. 11 agents, 11 commands (added `/init`), skill
`capability-orchestrator`. npm package **v0.4.0** is publish-ready: self-check
(validates plugin manifests when present, skips gracefully when not), prepack,
manual tarball allowlist/secret inspection, clean install, local scaffold, CLI
help, and `npm publish --dry-run` are GREEN. npm authentication is active; the
real publish remains an explicit human action.

## Done
- Engineered loop with two human gates; hard validation; reviewer + security
  every iteration (combined into one dispatch for trivial/small, separate for
  medium/large — see ADR-006); retry cap and one-COMMIT default budget.
- Eleven specialist agents, eleven commands, task graphs, dependency-aware
  SELECT, model routing (`implementer` / `implementer-opus`), and MCP scout.
- Capability orchestration (ADR-003): local skill discovery, hierarchical caps,
  AGENT_TASK contract, and guarded worktree fan-out.
- AI OS control plane: persistent events, scorecard→SELECT, budget stop, leases,
  harness CI, hard protected-path hooks, and brownfield bootstrap.
- Build-effort dial (ADR-004): `fast|standard|rigorous` from PRD/PTR; review and
  security remain mandatory on all tiers.
- User-level-only statusline; `--config-dir` wires `statusLine` to that dir’s
  script (default install still uses `$HOME/.claude`).
- npm package v0.4.0 metadata, allowlisted files, MIT license, zero dependencies.
  CI also runs on push to `v2-os`.
- Plugin packaging (ADR-005): `.claude-plugin/plugin.json` (`master`) +
  `marketplace.json` (`claude-master-setup`); `/master:init` bridges
  plugin-only installs into the project-local gated loop. Validated via
  `claude plugin validate .` and an isolated-sandbox install; not yet
  published/announced as a public marketplace source.
- **Ceremony dial (ADR-006):** `planner` skipped (orchestrator plans inline)
  for a strict 5-condition `trivial` checklist, with a fresh-GATE-1 escape
  hatch if BUILD reveals it wasn't actually trivial; `reviewer`+`security`
  combine into one `security`-persona (opus) dispatch for trivial/small;
  `docs/SESSION.md` moved from every-COMMIT to `/handoff`-only; `fast`-tier
  bootstrap now skips creating irrelevant surface docs entirely. `loop.json`
  gained `plan_source`/`review_dispatch`. All five hard invariants
  (VALIDATE/REVIEW/SECURITY/GATE1/GATE2) unchanged — verified GREEN via
  self-check, npm test, npm pack, and a fresh scratch-dir `--local` smoke test.
- **Fixed:** `.github/workflows` no longer leaks into consumer projects on
  `--local` installs (was unconditional; harness-ci.yml is meta-CI for this
  repo only) — confirmed via a fresh scratch-dir smoke test.

## In progress
- None. Branch `v2-os` is ready for final push/tag/publish approval.

## Next up
1. Push `v2-os`, tag `v0.4.0`, and publish v0.4.0 when approved (now includes
   `.claude-plugin/` and the ceremony-dial changes).
2. Announce/publish the `claude-master-setup` marketplace publicly (currently
   only sandbox-tested locally).
3. Watch real usage of the ceremony dial (ADR-006) — if the `trivial`
   eligibility checklist proves too permissive or GATE 1 alone isn't catching
   misjudged inline plans, tighten the checklist rather than redesigning.
4. Later: full Scheduler, benchmark suite, subjective evaluation, template
   library.

## Known issues / risks
- Permission allowlists and hooks are defense-in-depth, not a same-user sandbox;
  use a VM for untrusted prompts (`docs/SECURITY.md`).
- Budget, leases, and event history are cooperative local controls, not
  cryptographic enforcement.
- Full Scheduler, benchmarks, and subjective metrics remain explicitly
  unimplemented.
- ADR-006's inline-plan path removes the independent planner opinion for
  `trivial` tasks — GATE 1 (human) is the sole backstop there; watch real
  usage per "Next up" above.

## Blocked / needs human
- Approval for external `git push`, release tag, and `npm publish`.
