# Project State

> The first file a new session reads after `CLAUDE.md`. Updated by `docs-writer`
> after every loop iteration. Current state only — no history (that's CHANGELOG).

## Status
Harness is an autonomous software engineering / **AI OS** layer on Claude Code
(ADR-001/003). Milestones 0–2 (objective eval), 4 (capability orchestration),
**5 (AI OS control plane)**, and the plugin-packaging slice of Milestone 3
(ADR-005) are complete. Build-effort dial (ADR-004), a complexity-aware
ceremony dial (ADR-006), and a **shared-framework distribution model**
(ADR-007) round out the current shape: every install path (`--global`,
`--local`, the `master` plugin) now leaves a project with only `.master/`
(state + its own docs) + `CLAUDE.md` — the framework itself lives once,
shared, never duplicated into a project. 11 agents, 11 commands, skill
`capability-orchestrator`. npm package **v0.4.0** is publish-ready: self-check,
prepack, and `npm publish --dry-run` are GREEN. Real publish remains an
explicit human action.

## Done
- Engineered loop with two human gates; hard validation; reviewer + security
  every iteration (combined into one dispatch for trivial/small, separate for
  medium/large — ADR-006); retry cap and one-COMMIT default budget.
- Eleven specialist agents, eleven commands, task graphs, dependency-aware
  SELECT, model routing (`implementer` / `implementer-opus`), and MCP scout.
- Capability orchestration (ADR-003): local skill discovery, hierarchical caps,
  AGENT_TASK contract, and guarded worktree fan-out.
- AI OS control plane: persistent events, scorecard→SELECT, budget stop, leases,
  harness CI, hard protected-path hooks, and brownfield bootstrap.
- Build-effort dial (ADR-004): `fast|standard|rigorous` from PRD/PTR; review and
  security remain mandatory on all tiers.
- Plugin packaging (ADR-005): `.claude-plugin/plugin.json` (`master`) +
  `marketplace.json` (`claude-master-setup`); `claude plugin validate .`
  passes; not yet published/announced as a public marketplace source.
- Ceremony dial (ADR-006): `planner` skipped for a strict 5-condition
  `trivial` checklist (fresh-GATE-1 escape hatch if misjudged); `reviewer`+
  `security` combine into one `security`-persona (opus) dispatch for
  trivial/small; `SESSION.md` moved to `/handoff`-only; `fast`-tier bootstrap
  skips irrelevant surface docs. All five hard invariants unchanged.
- **Shared-framework model (ADR-007):** `.master/`-only project footprint on
  every install path. Verified end-to-end, not just written: fresh
  `--global`/`--local` installs in isolated sandboxes; confirmed token
  substitution (`${CLAUDE_PLUGIN_ROOT}` → real absolute path) landed correctly
  in copied agent files; confirmed the shared `validate.sh`/`loop-event.sh`/
  `session-start.sh` correctly operate on a separate sandboxed project
  (`$CLAUDE_PROJECT_DIR`-based resolution), not on the framework location
  itself or on themselves. `self-check`/`npm test`/`npm pack --dry-run`/
  `claude plugin validate .` all GREEN after the full migration.
- Global `~/.claude` cleanup: prior stale installer output (agents, commands,
  `claude-master-setup/` + backups, `statusline.sh`) removed, verified clean;
  a mid-work mistake (an accidental real `--global` install during testing)
  was caught and surgically reverted (only the exact entries that install
  added, not a blind wipe) before it could confuse the human's own fresh
  install.
- Fixed: `.github/workflows` no longer leaks into consumer projects on
  `--local` installs.

## In progress
- None. Branch `v2-os` is ready for final push/tag/publish approval.

## Next up
1. Push `v2-os`, tag `v0.4.0`, and publish when approved.
2. Human runs a genuinely fresh `npx claude-master-setup` to test the new
   `.master/`-only model firsthand (global `~/.claude` was cleaned for exactly
   this).
3. Announce/publish the `claude-master-setup` marketplace publicly (currently
   only sandbox-tested locally).
4. **Deliberately left open, not silently resolved:** the `Bash(bash
   scripts/:*)`-style tool-permission allowlist patterns in
   `.claude/settings.json` and several agent/command frontmatter blocks are
   literal-prefix matches that won't match the new absolute-path script
   invocations from the shared framework location. Blocked twice by the
   permission classifier as a self-modification requiring explicit,
   named authorization — needs the human to decide: a narrow additive pattern
   (`Bash(bash */scripts/*.sh:*)`, confirmed technically valid against Claude
   Code's wildcard docs) vs. a broader `Bash(bash *)`, vs. leaving it as an
   extra permission prompt on first use per session (current state — not
   broken, just occasional friction).
5. Watch real usage of the ceremony dial (ADR-006) and the shared-framework
   model (ADR-007) — tighten either if real use surfaces a gap.
6. Later: full Scheduler, benchmark suite, subjective evaluation, template
   library.

## Known issues / risks
- Permission allowlists and hooks are defense-in-depth, not a same-user sandbox;
  use a VM for untrusted prompts (`docs/SECURITY.md`).
- Budget, leases, and event history are cooperative local controls, not
  cryptographic enforcement.
- Full Scheduler, benchmarks, and subjective metrics remain explicitly
  unimplemented.
- ADR-006's inline-plan path removes the independent planner opinion for
  `trivial` tasks — GATE 1 (human) is the sole backstop there.
- Running the npm-installed framework *and* the `master` plugin on the same
  machine double-fires hooks (ADR-007) — the two paths are meant to be
  mutually exclusive per machine, not deduped automatically.
- The tool-permission allowlist gap in "Next up" #4 means script invocations
  from the shared framework location may prompt for permission on first use
  per session until resolved.

## Blocked / needs human
- Approval for external `git push`, release tag, and `npm publish`.
- The tool-permission allowlist decision (see "Next up" #4).
