---
description: Run configured checks and save validation evidence
argument-hint: "[--run ID]"
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Validate

Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" validate "$ARGUMENTS" --agent claude-code --format json
```

If validation is red, inspect the referenced evidence logs and fix the failure. Do not weaken required checks.
