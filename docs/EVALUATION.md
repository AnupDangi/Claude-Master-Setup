# Evaluation Framework

**Status: objective slice built.** `/evaluate` and the `evaluator` report Tests,
Iterations (loop events plus git as a secondary proxy), Documentation
completeness, and Manual Interventions from the persistent event log. The
scorecard is persisted for SELECT bias. Subjective metrics below (Planning,
Architecture, Security quality, Performance) remain intentionally deferred.

## Why

The harness's biggest credibility gap is that it currently *asserts* it
produces good engineering — no measurement backs that up beyond "tests pass."
An evaluation framework turns that into a number a user can look at, compare
across projects, and track over time.

## What `/evaluate` reports today

```
Tests                  GATE: GREEN (scripts/validate.sh)
Iterations             12   (loop-event loop_commits; git commits as secondary)
Documentation          6/9 template docs filled  (completeness, not quality)
Manual Interventions   2    (await_human_on_red + gate rejects from event log)
```

Persisted to `.claude/state/last_scorecard.json` via `scripts/write-scorecard.sh`
for orchestrator SELECT bias — see [`AI_OS.md`](AI_OS.md).

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
| Iterations | Prefer `scripts/loop-event.sh summary` → `loop_commits`; also report git commit count | Objective | **Built** (event log + git proxy) |
| Documentation completeness | Ratio of fill-on-bootstrap template docs still containing placeholder markers vs. filled in | Objective | **Built** |
| Manual Interventions | Count of `await_human_on_red` + `gate1_reject` + `gate2_reject` in event log | Objective | **Built** via `scripts/loop-event.sh` |

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
- **Don't fabricate a metric.** Manual Interventions comes only from
  `scripts/loop-event.sh`; coverage says "not reported by this stack" when the
  test runner does not produce it. A missing signal is not license to estimate.
- **Manual Interventions** is fed by `scripts/loop-event.sh` (see
  [`AI_OS.md`](AI_OS.md)). Orchestrator must emit events for the metric to move.
- **Score before you build the corpus.** A single benchmark run against one
  project proves nothing about general quality; the "Benchmarks" idea
  (running the harness against known reference projects — a Linear clone, a
  small CRM, etc. — to get comparable scores) is a separate, larger effort and
  is intentionally **out of scope** until this per-project scorecard exists
  and is trusted on its own.

## Continuous improvement loop

`/evaluate` persists `.claude/state/last_scorecard.json`; the orchestrator reads
it during SELECT. Current feedback is deliberately narrow: RED tests bias toward
fix/test work, low documentation completeness biases toward already-existing
docs work, and high manual interventions favors smaller slices or escalation.
The scorecard never invents roadmap items. Rich value/risk ranking remains a
future full Scheduler capability.
