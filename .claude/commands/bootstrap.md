---
description: Compatibility alias for Agent Master init
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Bootstrap Compatibility

`/bootstrap` is retained for existing users. Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" init
```

Report that the universal Agent Master project contract is ready. New documentation should use `/master:init` for the plugin or `agent-master init` in a terminal.
