# Evaluation Framework

**Status: partially built.** `/evaluate` and the `evaluator` subagent exist
(`.claude/commands/evaluate.md`, `.claude/agents/evaluator.md`) and report
**objective metrics only** — Tests, Iterations (a proxy), Documentation
completeness, and an honest "not tracked" for Manual Interventions. The
subjective metrics below (Planning, Architecture, Security quality,
Performance) are still design-only, deliberately sequenced after the
objective slice per `docs/ROADMAP.md` Milestone 2.

## Why

The harness's biggest credibility gap is that it currently *asserts* it
produces good engineering — no measurement backs that up beyond "tests pass."
An evaluation framework turns that into a number a user can look at, compare
across projects, and track over time.

## What `/evaluate` reports today

```
Tests                  GATE: GREEN (scripts/validate.sh)
Iterations             23   (git commit count — a proxy, not a true loop count)
Documentation          6/9 template docs filled  (completeness, not quality)
Manual Interventions   not tracked (no persistent event log — see Backlog)
```

## Target: full `/evaluate` scorecard

```
Planning              9.6
Architecture          9.1
Tests                 95%
Coverage              91%
Documentation         9.7
Security              8.8
Performance           9.2
Manual Interventions  2
Iterations            18
```

## Metric sources

Not every metric is computed the same way — be explicit about which are
objective (pulled from tooling) versus subjective (an LLM judgment call), so
the scorecard doesn't overstate its own precision:

| Metric | Source | Kind | Status |
|---|---|---|---|
| Tests | `GATE: GREEN\|RED` from `scripts/validate.sh`; coverage % only if the stack's test runner reports one | Objective | **Built** |
| Iterations | `git log --oneline \| wc -l` (or since a given ref) | Objective, but a proxy — counts every commit, not only loop-driven ones; no structured iteration log exists | **Built (proxy)** |
| Documentation completeness | Ratio of fill-on-bootstrap template docs still containing placeholder markers vs. filled in | Objective | **Built** |
| Manual Interventions | Would need a count of `await-human-on-red` escalations + non-trivial GATE 1/2 rejections | Objective in principle | **Not tracked** — `.claude/state/loop.json` holds only current state, not history; a persistent event log is a prerequisite (see Backlog in `docs/ROADMAP.md`) |
| Token usage / est. cost | Sum of per-iteration usage, if tracked | Objective (requires new tracking — not collected today) | Not built |
| Planning quality | An evaluator reviews `docs/DECISIONS.md` + planner outputs against the DoD they set | Subjective (LLM-judged) | Not built — deliberately deferred until objective metrics are trusted |
| Architecture | An evaluator reviews ADRs and structure against the stated constraints | Subjective (LLM-judged) | Not built |
| Documentation quality | As opposed to completeness above — an evaluator judges whether what's written is actually good | Subjective (LLM-judged) | Not built |
| Security | Aggregated severity of open/resolved findings from the `security` agent | Semi-objective (counts, weighted by severity) | Not built |
| Performance | Project-specific; no default metric — only meaningful if the project defines one | Subjective / project-defined | Not built |

## Design constraints for whoever builds the rest of this

- **Read-only.** `evaluator` never fixes what it scores low on — same
  separation of concerns as `reviewer`/`security`. Keep this true for any
  subjective-metric extension too.
- **Don't fabricate a metric.** `evaluator` reports "not tracked" for Manual
  Interventions rather than guessing, and "not reported by this stack" for
  coverage when the test runner doesn't produce one. Any new metric should
  follow the same rule — a missing signal is not license to estimate one.
- **Manual Interventions needs a prerequisite, not just more prompt logic.**
  It requires a persistent event log — `.claude/state/loop.json` only holds
  current state. Add that log (append-only, e.g. one line per
  `await-human-on-red` entry and per non-trivial gate rejection) before
  attempting this metric; see the Backlog in `docs/ROADMAP.md`.
- **Score before you build the corpus.** A single benchmark run against one
  project proves nothing about general quality; the "Benchmarks" idea
  (running the harness against known reference projects — a Linear clone, a
  small CRM, etc. — to get comparable scores) is a separate, larger effort and
  is intentionally **out of scope** until this per-project scorecard exists
  and is trusted on its own.

## Continuous improvement loop

`/evaluate`'s output is designed to be the natural input to the Loop Engine's
**Measure** and **Update Memory** stages (`LOOP_ENGINE.md`): a scheduler that
knows an iteration scored low on Planning could weight more architect
involvement into the next SELECT decision, instead of that signal being
discarded after the human reads it once. Nothing consumes `/evaluate`'s output
automatically yet — that's `docs/ROADMAP.md` Milestone 2's third item, and it's
gated on the Scheduler existing to consume it, same as dynamic model routing
is gated on named agent variants existing.
