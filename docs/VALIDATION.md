# Harness Validation

> Evidence that the harness in this repo actually works — not just that its
> files are wired correctly (`scripts/self-check.sh`), but that a real
> product increment can be planned, built, validated, and reviewed by the
> actual subagents defined in `.claude/agents/`, ending in working code.

## What was tested

**Structural (mechanics):**
- `git apply` of the harness onto a clean checkout, `scripts/install.sh`,
  `scripts/self-check.sh` — all agents/commands/hooks/scripts/docs verified
  present and correctly wired.
- `scripts/detect-stack.sh` + `scripts/validate.sh` run against throwaway
  Node and Python scratch projects outside this repo, proving stack
  detection and the GREEN/RED gate are genuinely project-agnostic (not
  hardcoded to this repo) — including a deliberately broken test to confirm
  RED actually fires, not just GREEN.

**End-to-end (a real product, real agents):** a fresh throwaway project
(`wordcount`, a small Node CLI with zero dependencies) was scaffolded from
this harness and taken through:

1. **Bootstrap** — the `architect` persona (dispatched as a real subagent,
   not simulated) evaluated the proposed stack, accepted it, and wrote
   Decision 001 to `docs/DECISIONS.md` plus a filled `docs/ARCHITECTURE.md`.
2. **SELECT → PLAN** — the `planner` persona turned two roadmap items into
   one concrete, file-by-file plan with a Definition of Done, correctly
   proposing to combine Milestone 0+1 into one shippable slice with a
   reasoned justification.
3. **GATE 1** — a real human approval was required and given (not
   auto-approved) before any code was written.
4. **BUILD** — the `implementer` persona wrote `package.json`, a pure
   IO-free counting core, a CLI shell, and two test files (9 tests total),
   staying exactly in scope (did not implement out-of-scope flags).
5. **VALIDATE** — the `validator` persona was explicitly instructed *not* to
   trust the implementer's self-reported GREEN, and re-ran
   `scripts/validate.sh` independently, confirming exit 0 for real.
6. **REVIEW** — the `reviewer` persona found two genuine (non-blocking)
   Medium/Low findings — ASCII-only tokenization and undocumented apostrophe
   handling — proving it does not rubber-stamp; it was not asked to invent
   findings and found real ones on its own.
7. **GATE 2** — a real human approval was required and given for the merge,
   with the review findings explicitly logged to the backlog rather than
   silently dropped.
8. **COMMIT** — one atomic, conventional commit; docs (`PROJECT_STATE.md`,
   `ROADMAP.md`, `CHANGELOG.md`) updated in the same iteration.
9. **Manual smoke test** — the built CLI was run directly against a real
   input file (outside any test harness) and produced correct, ordered word
   counts, plus correct non-zero exits and stderr messages for a missing
   file and a missing argument.

## Result

The loop worked as designed on the first real run, with no orchestrator
intervention needed to correct a subagent's output. Both approval gates were
exercised for real (not skipped or self-approved), the validation gate was
independently re-checked rather than trusted, and the review step produced
substantive, non-trivial findings rather than a rubber stamp.

## Honest limitations found

- **Subagent registration is manual outside a live Claude Code session.**
  This evaluation ran inside a single Claude Code session using the
  general-purpose Task/Agent mechanism with each `.claude/agents/*.md`
  persona's full body pasted into the dispatch prompt (matching model
  routing per agent, e.g. `architect`/`planner` on opus, `implementer`/
  `validator`/`reviewer` on sonnet). This is functionally equivalent to how
  Claude Code's native subagent registration works (system prompt = agent
  file body, tools = its `tools:` frontmatter), but it means `/loop` run
  *for real* inside the target project (where Claude Code auto-registers
  `.claude/agents/*.md` as native subagent types) is the actual intended
  path — this evaluation is strong evidence the design works, not a
  substitute for using `/bootstrap` → `/loop` directly.
- **This historical run predates the current always-security invariant.**
  Security was omitted because the increment was a local CLI with no auth,
  secrets, payments, or network. In v0.4 the orchestrator runs `security` every
  iteration (a light residual-risk pass is sufficient for low-risk/pure-docs
  changes), so reproductions must include it before GATE 2.
- Review findings (non-ASCII tokenization, apostrophe handling) were real
  and correctly deferred to backlog rather than blocking — but this also
  means "GREEN" only certifies what the Definition of Done actually scoped,
  not full correctness for every possible input. That is by design (small
  shippable units), not a harness defect.

## How to reproduce

See `docs/LOOP.md` for the phase spec and `docs/SETUP.md` for the quick
start. Any project can repeat this by adding its own `PRD.md`/`PTR.md` and
running `/bootstrap` then `/loop` inside a real Claude Code session.
