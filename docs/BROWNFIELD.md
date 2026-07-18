# Brownfield adoption

> How `/bootstrap` behaves when the repo already has code (not greenfield
> PRD/PTR-only).

## Detect brownfield

Any of:

- `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `pom.xml`,
  `build.gradle`, `Gemfile`, `composer.json` present
- Non-empty `src/`, `app/`, `lib/`, or language-typical roots
- Existing git history with commits

Greenfield remains: empty or docs-only tree + user-supplied `PRD.md`/`PTR.md`.

## Bootstrap flow (brownfield)

1. **Detect stack** — `bash scripts/detect-stack.sh` (and read manifests).
2. **Inventory** — list entrypoints, test runner, lint/build scripts, env needs.
3. **Clarify with human** — mission, must-not-break invariants, target quality bar.
4. **Draft requirements** — write `PRD.md`/`PTR.md` that describe *what exists*
   plus *what to improve*, not a fantasy rewrite.
5. **Architect** — ADRs for current decisions; note debt without boiling the ocean.
6. **Docs** — fill `docs/` from reality; mark unknowns honestly.
7. **Roadmap (coarse)** — prefer:
   - make `validate.sh` GREEN (tests/lint wired)
   - docs/security baseline
   - one vertical improvement slice
   Avoid 15 micro-tasks on day one.
8. **Stop for approval** — no feature code in bootstrap.

## Anti-patterns

- Rewriting the stack during bootstrap
- Inventing modules that don't exist
- Ignoring existing tests/CI
- Over-slicing the adoption roadmap
