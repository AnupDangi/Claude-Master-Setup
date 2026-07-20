# Repo-first bootstrap

`/bootstrap` prepares minimal project context. It does not implement features or
write a documentation suite.

**Note**: The command is `/bootstrap` — not `/boostrap` (common typo).

## Read before writing

1. README and project manifests
2. source entrypoints and directory structure
3. tests, lint/build scripts, and CI configuration
4. PRD/PTR only when present (they supplement, never override, repository facts)

Classify maturity from evidence: `new`, `prototype`, `existing`, or `production`.
Do not ask questions unless an unknown would make the generated project context
incorrect.

## Greenfield slicing

For new/empty repos with a product vision in `$ARGUMENTS`:
- Identify the smallest shippable slice (not the full vision)
- The first `/loop` task should deliver one concrete user-facing behaviour
- Do not scaffold the entire architecture upfront

## Write only

- `CLAUDE.md`: project name, mission, stack, run/verify commands, conventions;
  target 40 lines or fewer; zero harness architecture prose.
- `.master/project.json`: structured facts, entrypoints, commands, maturity,
  validation command, `iteration_budget`, and `docs.manifest`/`docs.load_for_loop`
  for existing/production projects.
- `.master/state/loop.json`: idle machine state.
- `.master/docs/ROADMAP.md`: optional, maximum four outcome lines, only when a
  roadmap can be grounded in README/PRD/current issues.
- `.master/docs/DESIGN.md`: for visual products only (web app, mobile, desktop UI) —
  colors, fonts, layout intent, component hierarchy. Trigger: `$ARGUMENTS` mentions
  design/UI/frontend/web app/visual.
- `.master/docs/DECISIONS.md`: stub for greenfield projects tracking architecture decisions.

## Progressive docs (not at bootstrap)

Do NOT generate at bootstrap time:
- API.md — add at SHIP when routes are implemented
- DATABASE.md — add at SHIP when schema is defined
- SECURITY.md — add at SHIP for auth/payment/sensitive features
- TESTING.md — add at SHIP when test suite is meaningful
- DEPLOYMENT.md — add at SHIP when deployment is configured

## Iteration budget

Set `iteration_budget` in project.json based on maturity:
- `new`: 3
- `prototype`: 3
- `existing`: 5
- `production`: 7

This is advisory; `--max-iterations` overrides it per loop invocation.

Reuse existing project documentation. When done, report what was inferred and suggest:
`/loop "first concrete task"` (default two iterations).
