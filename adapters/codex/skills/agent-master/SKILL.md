---
name: agent-master
description: Resume and manage portable repository work through the Agent Master CLI. Use when a repository contains `.master/`, when continuing work started by Claude Code or Cursor, or when starting, validating, checkpointing, handing off, pausing, cancelling, or completing an Agent Master run.
---

# Agent Master

Use the repository's `.master/` state to exchange work with other coding agents. Keep Codex goals, memories, subagents, and plugins native to Codex; record only portable task facts in Agent Master.

## Resume Existing Work

1. Read `AGENTS.md` and `.master/project.json`.
2. Run `agent-master status --format json`.
3. Verify the recorded branch, HEAD commit, changed files, and working-tree cleanliness with git.
4. Treat repository evidence as authoritative when it differs from recorded state.
5. Continue from `next_action`.

Use Codex `/goal` for a long-running Codex task when appropriate. Do not copy Codex memory into `.master/`.

## Record Progress

Checkpoint facts that another agent needs:

```bash
agent-master checkpoint --agent codex \
  --completed "Implemented refresh-token rotation" \
  --decision "Store only hashed refresh tokens" \
  --remaining "Add replay protection test" \
  --next "Run the authentication integration suite"
```

Use repeated flags for multiple decisions, completed items, remaining tasks, or blockers.

## Validate And Complete

Run configured project checks and preserve their output:

```bash
agent-master validate --agent codex
agent-master complete --agent codex
```

Completion must fail when validation is missing, red, or stale. Inspect the referenced evidence logs, fix failures, and validate again. Never weaken project checks to obtain GREEN.

## Hand Off Or Pause

Before ending an unfinished task, checkpoint accurate progress and run one of:

```bash
agent-master handoff --agent codex --next "First action for the next agent"
agent-master pause --agent codex --blocker "Required decision or dependency"
agent-master cancel --agent codex --reason "Why this run is no longer needed"
```

Release file claims or hand off the run so another agent can continue safely.
