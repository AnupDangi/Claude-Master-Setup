---
description: Run the objective-metrics evaluation scorecard against the current project
argument-hint: [optional: since=<git-ref> to scope the iteration count]
allowed-tools: Read, Grep, Glob, Task, Bash(git log:*), Bash(bash scripts/:*)
model: sonnet
---

# Evaluate

Delegate to the **evaluator** subagent to produce the scorecard described in
`docs/EVALUATION.md` and `.claude/agents/evaluator.md`.

$ARGUMENTS

This reports Tests, Iterations, Documentation completeness, and Manual
Interventions (currently `not tracked` — the harness keeps no persistent event
log). It does **not** score Planning, Architecture, Security, or Performance —
those are subjective and deliberately deferred; see `docs/ROADMAP.md`
Milestone 2 and `docs/EVALUATION.md`.
