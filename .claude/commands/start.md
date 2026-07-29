---
description: Start a portable Agent Master run
argument-hint: "GOAL [--run ID]"
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Start

Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" start "$ARGUMENTS" --agent claude-code --format json
```

Verify repository state, then continue from `next_action`.
