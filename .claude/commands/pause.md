---
description: Pause an active loop with a concise blocker for another session
argument-hint: [reason]
allowed-tools: Read, Write, Edit, Bash(python3 */scripts/write-handoff.py:*)
model: sonnet
---

# Pause

## Role

You persist a **blocker into durable state** so a future session can resume without chat history.

## Update `.master/state/loop.json`

- `active: false`
- `status: "paused"`
- `pause_reason`: `$ARGUMENTS` or the concrete blocker
- `next_action: "await_human"`
- `updated_at`: ISO-8601 UTC now
- If architecture decision needed: `architecture_pending: true`
- If clarifying questions remain: `await_clarify_questions: ["1. …", …]`

Then: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/write-handoff.py "${CLAUDE_PROJECT_DIR:-$PWD}"`

## Report

Blocker + what must happen before `/loop` continues. No Markdown session docs.
