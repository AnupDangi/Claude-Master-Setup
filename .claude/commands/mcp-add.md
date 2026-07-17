---
description: Check if a tool has an MCP server and add it to .mcp.json (with consent)
argument-hint: <tool or service, e.g. "postgres" or "github">
allowed-tools: Task, Read, Grep, Glob, WebSearch, Write, Edit, Bash(bash scripts/:*), Bash(cat:*)
model: sonnet
---

# Add MCP Server

Catalog: !`cat scripts/mcp-catalog.json 2>/dev/null | head -5 || echo "catalog missing"`
Existing servers: !`cat .mcp.json 2>/dev/null || echo "no .mcp.json yet"`

Delegate to the **mcp-scout** subagent for:

$ARGUMENTS

The scout must: (1) check `scripts/mcp-catalog.json`, then the web; (2) **ask for explicit consent before editing `.mcp.json`**; (3) on yes, add the server with `${ENV_VAR}` references only (no literal secrets), update `.env.example` and `docs/MCP.md`, and tell me which env vars to set and that I must restart Claude Code to connect it. If no real server exists for the tool, say so — don't invent one.
