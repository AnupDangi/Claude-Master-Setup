---
description: Inspect the active Agent Master run
argument-hint: "[--run ID]"
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Status

Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" status "$ARGUMENTS" --format json
```

Verify the recorded branch, commit, changed files, and working-tree cleanliness with git. Repository evidence wins when recorded state is stale.
