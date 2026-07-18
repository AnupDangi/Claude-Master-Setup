---
description: Run the objective-metrics evaluation scorecard against the current project
argument-hint: [optional: since=<git-ref> to scope the git commit proxy]
allowed-tools: Read, Grep, Glob, Task, Bash(git log:*), Bash(bash scripts/:*)
model: sonnet
---

# Evaluate

**Intent:** produce the objective engineering scorecard and persist it for SELECT feedback.

Delegate to the **evaluator** subagent (`docs/EVALUATION.md`, `docs/AI_OS.md`,
`.claude/agents/evaluator.md`). It must call `scripts/write-scorecard.sh` so
`.claude/state/last_scorecard.json` updates.

$ARGUMENTS

Reports Tests, Iterations (prefer `loop-event.sh` `loop_commits`), Documentation
completeness, and Manual Interventions (from the event log). Does **not** score
subjective Planning/Architecture/Security/Performance — see `docs/EVALUATION.md`.
