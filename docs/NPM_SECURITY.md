# npm package security (Socket.dev)

`claude-master-setup` is an **installer**: it copies harness files into
`~/.claude` or `./.claude` and merges recommended plugin flags into
`settings.json`. That requires filesystem writes by design.

## What this package does *not* do (0.2.4+)

- No `child_process` / shell execution in `bin/cli.js`
- No `process.env` reads in the installer (use `--config-dir` instead)
- No network fetches from the installer itself
- No postinstall / preinstall npm lifecycle scripts
- No runtime dependencies

## Companion plugins

The installer only **merges** marketplace / `enabledPlugins` entries. Downloading
plugins is a **separate, user-run** step via the Claude Code CLI or `/plugin`
(see [`COMPANIONS.md`](COMPANIONS.md)).

## Expected scanner alerts

| Alert | Expected? | Why |
|---|---|---|
| Filesystem access | Yes | Installer must write agents/commands/docs |
| Shell access | No (fixed in 0.2.4+) | Removed from CLI |
| Environment variable access | No (fixed in 0.2.4+) | Removed from CLI |
| URL strings | Minimal | CLI avoids hardcoded fetches |
| AI / installer anomaly | Possible | Heuristic for “copies files to home” |

## Report issues

https://github.com/AnupDangi/Claude-Master-Setup/issues
