---
description: Complete a run only with current GREEN evidence
argument-hint: "[--run ID]"
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Complete

Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" complete "$ARGUMENTS" --agent claude-code --format json
```

If completion is rejected, report the stale or failed validation reason and continue the work.
