# Coding Standards

> Full detail here; the summary lives in `CLAUDE.md`. The implementer and reviewer
> enforce this. Fill in the language/framework specifics on bootstrap.

## Language & style
- _(language version, formatter, linter, and their configs — these are what
  `validate.sh` runs)_

## Naming
- _(files, modules, functions, constants, tests)_

## Structure
- _(where things live; how a new module/endpoint/component is laid out)_

## Error handling
- _(how errors are raised, wrapped, logged, surfaced; never swallow silently)_

## Tests
- _(framework, where tests live, naming, what "tested" means — see TESTING.md)_

## Comments & docs
- _(when to comment; docstring/JSDoc expectations; keep docs in sync with code)_

## Forbidden
- No debug prints (`console.log`, `print`) in committed code.
- No hardcoded secrets — use env vars.
- No duplicated business logic — reuse existing modules.
