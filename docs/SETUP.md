# Setup

## Plugin

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
- `.master/docs/ROADMAP.md` — one optional outcome stub
- `.master/docs/DESIGN.md` — visual products only (bootstrap-time)
- `.master/docs/DECISIONS.md` — architecture decision records (greenfield)
- Progressive docs at SHIP: API.md, DATABASE.md, SECURITY.md, TESTING.md, DEPLOYMENT.md

No `.env`, `.github`, framework agents/commands, empty documentation suite, statusline,
or maintainer files are copied into the project.

## Bootstrap maturity

`new`: no established source tree. `prototype`: source exists without tests.
`existing`: source and tests exist. `production`: tests and CI evidence exist.
Bootstrap refines this classification after reading repository content. For an intentional
docs-only repository, set `allow_no_stack: true` in `.master/project.json`;
otherwise an unknown stack validates RED.

## Iteration budget

`project.json` includes `iteration_budget` set at bootstrap:
- new/prototype: 3
- existing: 5
- production: 7

This is advisory; `--max-iterations` overrides per loop invocation.

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

## Update or uninstall

npm: rerun `npx claude-master-setup@latest`.
Plugin: refresh the marketplace and update/reinstall `master`.
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
