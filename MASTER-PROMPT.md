# Repo-first bootstrap

Loaded by `/bootstrap`. Keep this file short — detailed command behaviour lives in
`.claude/commands/bootstrap.md`.

**Command spelling:** `/bootstrap` (not `/boostrap`).

## Contract

`/bootstrap` creates minimal project memory. It does not implement features or
dump a documentation suite.

## Read before writing (order)

1. README and manifests
2. Source entrypoints and layout
3. Tests, lint/build scripts, CI
4. PRD/PTR only if present (never override repo facts)

Classify maturity from evidence: `new` | `prototype` | `existing` | `production`.
Ask questions only when an unknown would make generated context **incorrect**.

## Greenfield

With product vision in `$ARGUMENTS`: identify the **smallest shippable slice**.
First `/loop` delivers one concrete user-facing behaviour — not the full architecture.

## Write only (generate from evidence — never copy templates)

Write each file from scratch using repository facts. You may peek at
`${CLAUDE_PLUGIN_ROOT}/templates/master-docs/*.md` for **section names only** —
do **not** copy those files into the project.

- `CLAUDE.md` — ≤40 lines; name, mission, stack, run/verify, conventions; no harness prose
- `.master/project.json` — facts, maturity, validate_cmd, `iteration_budget`, docs flags for existing/production
- `.master/state/loop.json` — idle state
- `.master/docs/ROADMAP.md` — optional ≤4 grounded outcomes (create only if evidence warrants)
- `.master/docs/DESIGN.md` — visual products only (create only when UI evidence exists)
- `.master/docs/DECISIONS.md` — greenfield ADR stub (create only for greenfield)

## Not at bootstrap

API.md, DATABASE.md, SECURITY.md, TESTING.md, DEPLOYMENT.md — created progressively at SHIP
via `sync-project-docs.sh` or implementer appends (still generate, never bulk-copy templates).

## Iteration budget → loop default

| Maturity | `iteration_budget` |
|----------|-------------------|
| new / prototype | 3 |
| existing | 5 |
| production | 7 |

`setup-loop.sh` uses this as default `max_iterations` unless the user passes `--max-iterations`.

## Finish

Report inferences. Suggest: `/loop "first concrete task"`.
