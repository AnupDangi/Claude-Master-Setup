# Setup

**Product version:** 1.0.2 (stable). Prefer **one** install path: npm **or** plugin — never both.
Dual install double-fires hooks. Prefer npm; use `--repair` if both are active.
If switching to npm after using the plugin: `claude plugin uninstall master@claude-master-setup`, then `npx claude-master-setup@latest`.
If you previously used npm `0.6.x`, re-run `npx claude-master-setup@latest`.

## Marketplace updates (git-backed)

The plugin marketplace **is** this GitHub repo. Pushing to `main` publishes the
catalog. Claude Code periodically pulls marketplace remotes in the background.

Installed plugins are **version-pinned** via `.claude-plugin/plugin.json`. Pushing
commits without bumping `version` does **not** replace a user’s cached install.
For a release: bump `version` in `plugin.json` and `marketplace.json` (same string),
push — CI tags `master--v{version}`. Users then receive the update on auto-update
or `claude plugin update master@claude-master-setup`.

## Plugin

Use the plugin **instead of** npm — not in addition to it. If `~/.claude/claude-master-setup`
already exists from npm, either uninstall the npm framework + its settings hooks, or stay on npm
and skip the plugin.

```bash
claude plugin marketplace add AnupDangi/Claude-Master-Setup
claude plugin install master@claude-master-setup
```

Run `/master:bootstrap` inside a project, then `/master:loop "task"`.

## npm

```bash
cd your-project
npx claude-master-setup@latest
claude
```

Run `/bootstrap`, then `/loop "task"`.

The npm path installs one shared runtime under the selected Claude config directory
(including `statusline.sh` and `settings.json` statusLine wiring) and seeds the current
project. Existing project files are not overwritten.

## Consumer files

- `CLAUDE.md` — inferred project mission, stack, commands, conventions
- `.master/project.json` — structured project facts and maturity
- `.master/state/loop.json` — idle/active machine state
- `.master/docs/` — created empty on install; docs are **generated from evidence**
  at `/bootstrap` or SHIP (never bulk-copied from `templates/master-docs/`)
- Optional after bootstrap: `ROADMAP.md`, `DESIGN.md` (UI), `DECISIONS.md` (greenfield)
- Progressive at SHIP: API.md, DATABASE.md, SECURITY.md, TESTING.md, DEPLOYMENT.md
  via `sync-project-docs.sh` stubs or implementer appends

`templates/master-docs/` are **section outlines** for agents to peek at — not seed files.

No `.env`, `.github`, framework agents/commands, empty documentation suite, statusline,
or maintainer files are copied into the project.

## Bootstrap maturity

`new`: no established source tree. `prototype`: source exists without tests.
`existing`: source and tests exist. `production`: tests and CI evidence exist.
Bootstrap refines this classification after reading repository content. For an intentional
docs-only repository, set `allow_no_stack: true` in `.master/project.json`;
otherwise an unknown stack validates RED.

## runtime_check

`project.json` supports an optional `runtime_check` field (default `null`).
When set to a non-null shell command string, `validate.sh` runs it as the final stage
after stack checks. A non-zero exit makes the entire gate RED.

Bootstrap sets a conservative default only when an obvious smoke command exists
(e.g. `curl -sf http://localhost:3000/health`). Leave `null` when uncertain —
never invent a fragile check. Consumer opts in; the harness does not bundle Playwright
or any server runner.

```json
// .master/project.json
{
  "runtime_check": "curl -sf http://localhost:3000/api/health"
}
```

## Visual product gate (DESIGN.md)

If bootstrap detects UI/visual evidence (React, Vue, Svelte, mobile UI, Tailwind, etc.)
it **must** create `.master/docs/DESIGN.md`. Subsequent `/loop` runs check for it at
GATE: if the task is UI-related and DESIGN.md is missing, the loop pauses and asks
before entering BUILD. This prevents silent BUILD against an unspecified visual design.

## Iteration budget

`project.json` includes `iteration_budget` set at bootstrap:
- new/prototype: 3
- existing: 5
- production: 7

`/loop` (via `setup-loop.sh`) uses this as the default `max_iterations` when
`--max-iterations` is omitted. Explicit `--max-iterations` still wins.

## Phased pipeline

Every `/loop` invocation works through: GATE→PLAN→BUILD→VALIDATE→REVIEW→SHIP→COMPLETE.
The `phase` field in loop.json tracks progress. The Stop hook enforces all gates.

## Progressive docs

Docs are generated progressively to avoid wasting context:
- Bootstrap: CLAUDE.md, project.json, optional ROADMAP.md/DESIGN.md/DECISIONS.md
- SHIP: API.md, DATABASE.md, SECURITY.md, TESTING.md, DEPLOYMENT.md (via sync-project-docs.sh)
- `docs.load_for_loop: false` (default) keeps loop context lean

## Token economics

- Skills are stored as paths, not expanded into context
- Docs are loaded lazily (load_for_loop flag)
- Loop continuation uses a compact JSON summary, not full doc bundles
- select-skills.sh penalizes plugin skills for UI/design queries to boost project-local skills

## MCP disconnect

claude-mem is optional. If unavailable, `memory-pending.json` is written but ignored.
Repository state (loop.json, handoff.json) is always authoritative.

## Default skills

Every install runs `scripts/install-default-skills.sh`, which uses
[`npx skills`](https://github.com/vercel-labs/skills) to install the curated
allowlist from `templates/skills-allowlist.json` into `~/.claude/skills`
(`-g -a claude-code`). Failures are non-fatal. Undocumented escape hatch:
`MASTER_SKIP_SKILLS=1`.

### Runtime install (bootstrap / loop)

`setup-loop.sh` calls `ensure-skills.sh`, which:

1. Lists local skills
2. Matches the task against `runtime[]` in the allowlist
3. Installs up to two missing allowlisted skills via `install-skill.sh`
4. Re-runs `select-skills.sh` (≤3 injected paths)

```bash
bash scripts/install-skill.sh vercel-labs/agent-skills --skill "deploy-to-vercel"
bash scripts/install-skill.sh --list vercel-labs/agent-skills
bash scripts/install-skill.sh --suggest "improve react performance"
bash scripts/ensure-skills.sh "deploy the app to vercel" 3
```

Sources **not** in the allowlist are only suggested to the user:

```bash
npx skills add owner/repo --skill "Convex Best Practices" -g -a claude-code -y --copy
```

Set `MASTER_SKILLS_TRUST_ANY=1` only if you intentionally allow any `owner/repo`.

Claude plugins (claude-mem, superpowers, antigravity, …) are printed as install
hints only — never auto-installed.

`/loop` discovery order: project `.claude/skills` + `.agents/skills` →
`~/.claude/skills` → plugin skills. Ranking uses token match + catalog aliases
from the allowlist; at most three skills are injected.

## Doctor and repair

```bash
npx claude-master-setup --doctor          # exit 0 = healthy
npx claude-master-setup --repair          # dedupe hooks, restore framework, disable plugin if dual
npx claude-master-setup --doctor --config-dir /path/to/claude-config
```

`--doctor` checks: framework files, exactly one `harness:*` hook id each, no legacy
`HARNESS_FRAMEWORK_ROOT`, and dual install (npm + enabled plugin). It also **warns**
(does not delete) if the current project’s `.claude/settings.json` contains stale
foreign hooks (e.g. ECC `plugin-hook-bootstrap.js`).

`--repair` reinstalls the shared framework, rewrites hooks to one clean set, drops
legacy env keys, and disables `master@claude-master-setup` when the npm framework
is present.

## Project settings hygiene

Keep project `.claude/settings.json` free of foreign harness hooks. Claude Master
Setup never requires embedding its hooks in the project — they live in the global
config. Leftover hooks from other tools (Everything Claude Code, etc.) can flood
sessions with `MODULE_NOT_FOUND` errors after those tools are uninstalled; remove
them manually.

## Update or uninstall

**Hard rule:** use npm **or** the plugin — never both.

npm: rerun `npx claude-master-setup@latest` (or `--repair` to fix hook drift).
Plugin: refresh the marketplace and update/reinstall `master` — and do **not** keep
the npm `claude-master-setup` framework + hooks active on the same machine.
To uninstall npm runtime, remove the shared `claude-master-setup` directory and its
identified hook entries from Claude settings. Remove `.master/` only if project state
is no longer needed. To remove default skills: `npx skills remove --global …`.

## Original issue checklist

1. Project bootstrap, not harness documentation.
2. Generated `CLAUDE.md` is inferred from the repository.
3. Framework and project knowledge are separated.
4. README/manifests/source/tests are read before writing.
5. Repository evidence is the source of truth.
6. Default output is three structured files plus optional roadmap.
7. Duplicate project-state document templates were removed.
8. Simple work skips verbose planning.
9. Direct/delegated/parallel routing adapts to task size.
10. Completion uses one automated validation gate, not repeated approval ceremony.
11. Routing and specialist choice are task-dependent.
12. Independent complex slices can run in parallel worktrees.
13. Iterations read minimal JSON instead of a documentation bundle.
14. Machine state and handoff are JSON.
15. Framework docs remain in the shared install.
16. Bootstrap records project maturity.
17. Existing repository facts are reused, not regenerated speculatively.
18. Defaults optimize for shipping code with validation.
19. Direct mode reduces time-to-first-code.
20. Tests, validation, review for important changes, and resumable handoff protect quality.
21. Phased pipeline (GATE→PLAN→BUILD→VALIDATE→REVIEW→SHIP→COMPLETE) enforces quality gates.
22. Anti-stall detection prevents infinite retries on stuck work.
23. Progressive docs avoid context waste and premature documentation.
