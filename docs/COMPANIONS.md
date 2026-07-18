# Recommended companions

The harness works **without** these. Install them so sessions feel like a full
Claude Code engineering setup (persistent memory, process skills, skill library).

## Why

| Companion | Role |
|---|---|
| **claude-mem** | Persistent memory across sessions (auto-memory alone forgets) |
| **superpowers** | Brainstorming, TDD, systematic debugging workflows |
| **code-review** | Deeper review pass alongside `/review` |
| **antigravity-awesome-skills** | Large curated `SKILL.md` library (Antigravity / Claude Code) |

## After `npx claude-master-setup --global`

The installer **merges** marketplaces + `enabledPlugins` into
`~/.claude/settings.json`. It does **not** spawn a shell or download plugins
(keeps the npm package free of shell/network installer behavior).

Complete the download yourself (terminal or Claude Code TUI):

```bash
claude plugin marketplace add thedotmack/claude-mem
claude plugin install claude-mem@thedotmack --scope user

claude plugin install superpowers@claude-plugins-official --scope user
claude plugin install code-review@claude-plugins-official --scope user

claude plugin marketplace add sickn33/antigravity-awesome-skills
claude plugin install antigravity-awesome-skills@antigravity-awesome-skills --scope user
```

Or inside Claude Code:

```text
/plugin marketplace add thedotmack/claude-mem
/plugin install claude-mem@thedotmack
/plugin install superpowers@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin marketplace add sickn33/antigravity-awesome-skills
/plugin install antigravity-awesome-skills
```

Then **restart Claude Code**. Per repo: `/learn-codebase` once (claude-mem).

## Pairing with the harness

1. `/bootstrap` (or open an existing repo)
2. `/learn-codebase` once (claude-mem)
3. Keep `docs/PROJECT_STATE.md`, `docs/SESSION.md`, `docs/DECISIONS.md` as the
   durable source of truth — claude-mem is recall on top, not a replacement
4. Use `/loop` for the build loop; use superpowers / Antigravity skills when
   the task matches

## Security

See [`NPM_SECURITY.md`](NPM_SECURITY.md) for Socket.dev / installer threat notes.
