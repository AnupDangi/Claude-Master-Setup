---
description: Review the current diff (quality + security when relevant)
argument-hint: [optional: paths or PR to focus on]
allowed-tools: Task, Bash(git diff:*), Bash(git log:*), Read, Grep, Glob
model: sonnet
---

# Review

Diff under review: !`{ git diff --stat 2>/dev/null; git diff --cached --stat 2>/dev/null; } || echo "(no git diff)"`

1. Delegate to the **reviewer** subagent for a quality pass (severity-ranked, grouped by file).
2. If the change touches auth, input handling, secrets, payments, file uploads, or data access, ALSO delegate to the **security** subagent.
3. Consolidate findings, Critical first. Flag which findings should block merge.

Focus: $ARGUMENTS
