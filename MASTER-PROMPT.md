# Repo-first bootstrap

`/bootstrap` prepares minimal project context. It does not implement features or
write a documentation suite.

## Read before writing

1. README and project manifests
2. source entrypoints and directory structure
3. tests, lint/build scripts, and CI configuration
4. PRD/PTR only when present (they supplement, never override, repository facts)

Classify maturity from evidence: `new`, `prototype`, `existing`, or `production`.
Do not ask questions unless an unknown would make the generated project context
incorrect.

## Write only

- `CLAUDE.md`: project name, mission, stack, run/verify commands, conventions;
  target 40 lines or fewer; zero harness architecture prose.
- `.master/project.json`: structured facts, entrypoints, commands, maturity, and
  validation command.
- `.master/state/loop.json`: idle machine state.
- `.master/docs/ROADMAP.md`: optional, maximum four outcome lines, only when a
  roadmap can be grounded in README/PRD/current issues.

Reuse existing project documentation. Do not generate Architecture, Decisions,
Session, Project State, API, Database, Security, or Testing documents by default.

When done, report what was inferred and suggest:
`/loop "first concrete task"` (default two iterations).
