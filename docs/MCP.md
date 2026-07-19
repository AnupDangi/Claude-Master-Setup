# MCP Integration

MCP (Model Context Protocol) is how Claude Code talks to external tools — databases,
GitHub, browsers, payment processors, error trackers, docs sources. This harness
makes adding them a guided, consent-based step instead of guesswork.

## The flow

```
task needs a tool ─▶ mcp-scout checks scripts/mcp-catalog.json
                                    │ (miss)
                                    ▼
                          web search "<tool> MCP server"
                                    │
                                    ▼
                     asks you: "add <tool>? needs ${VARS}"  ◀── consent gate
                                    │ yes
                                    ▼
              writes .mcp.json (${ENV_VAR} refs) + documents env vars in README
                                    │
                                    ▼
                 you set env vars, restart Claude Code, /mcp to verify
```

Trigger it explicitly with **`/mcp-add <tool>`**, or the scout fires automatically
when a plan or dependency implies an external service.

## Rules the scout follows

1. **Consent first.** Nothing is written to `.mcp.json` until you say yes.
2. **No literal secrets.** Config carries only `${ENV_VAR}` references; secrets live
   in your environment. `.env` stays gitignored; document variable names in the README (or `.env.example` if the project already uses one).
3. **Least privilege.** Read-only DB users, `repo:read` PATs, `--read-only` flags —
   the scout recommends the narrowest scope that works.
4. **Verify before proposing.** A plausible package name isn't a real server. If the
   scout can't confirm one exists, it says so rather than inventing it.
5. **Don't over-connect.** Each server costs context and adds attack surface. Add
   only what the current task needs.

## `.mcp.json` format (project scope, committed)

```json
{
  "mcpServers": {
    "github":   { "type": "http",  "url": "https://api.githubcopilot.com/mcp/",
                  "headers": { "Authorization": "Bearer ${GITHUB_PAT}" } },
    "postgres": { "type": "stdio", "command": "npx",
                  "args": ["-y", "@modelcontextprotocol/server-postgres"],
                  "env": { "POSTGRES_CONNECTION_STRING": "${DATABASE_URL}" } }
  }
}
```

- `type`: `stdio` (local process) or `http` (remote, streamable — preferred over the
  deprecated `sse`).
- `${VAR}` and `${VAR:-default}` expansion works in `command`, `args`, `env`, `url`,
  and `headers`.
- Project-scoped servers in `.mcp.json` are committed and shared with the team.
  Claude Code prompts once to approve them on first use.

## Scope guide

| Scope | Where | Use for |
|---|---|---|
| project | `.mcp.json` (committed) | Servers this project needs (its DB, its error tracker) |
| user | `~/.claude.json` | Personal tools you want everywhere (filesystem, fetch, Context7) |
| local | user state, per project | A temporary personal override |

Narrower scope wins on name collision: local > project > user.

## The catalog

`scripts/mcp-catalog.json` ships with common tools pre-mapped (filesystem, github,
postgres, sqlite, playwright, sentry, notion, stripe, context7, fetch, supabase,
linear) — each with transport, config, required env vars, scope hint, and a security
note. It's a starting point the scout verifies, not gospel. Add project-specific
entries as you discover them so the next `/mcp-add` is instant.

## Activating a newly added server

1. Set the required env vars (see the project README / MCP note from the scout).
2. Restart Claude Code (a config change to `.mcp.json` needs a fresh session).
3. Run `/mcp` or `claude mcp list` to confirm it connected.
4. Approve the project-scoped server when Claude Code prompts.

## Manual alternative

You can always add a server from the terminal instead of via the scout:

```bash
claude mcp add --scope project --transport http github https://api.githubcopilot.com/mcp/ \
  --header "Authorization: Bearer $GITHUB_PAT"
```

This writes the same `.mcp.json`. The scout just adds consent, catalog lookup,
security defaults, and doc/env bookkeeping on top.
