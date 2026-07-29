---
description: Record portable progress, decisions, and next work
argument-hint: "[--run ID] [--completed TEXT] [--decision TEXT] [--remaining TEXT] [--blocker TEXT] [--next TEXT]"
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Checkpoint

Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" checkpoint "$ARGUMENTS" --agent claude-code --format json
```

Keep entries factual and grounded in the current repository.
