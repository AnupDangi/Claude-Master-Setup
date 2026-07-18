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

## One-time setup (inside Claude Code)

After `npx claude-master-setup --global` (or `--local`), restart Claude Code, then:

```text
/plugin marketplace add thedotmack/claude-mem
/plugin install claude-mem@thedotmack

/plugin install superpowers@claude-plugins-official
/plugin install code-review@claude-plugins-official

/plugin marketplace add sickn33/antigravity-awesome-skills
/plugin install antigravity-awesome-skills
```

The installer also **merges** these marketplaces / enable flags into
`~/.claude/settings.json` (Forge-style). You still run `/plugin install …`
once so Claude Code downloads the plugin bits.

## Pairing with the harness

1. `/bootstrap` (or open an existing repo)
2. `/learn-codebase` once (claude-mem) so later sessions have repo context
3. Keep `docs/PROJECT_STATE.md`, `docs/SESSION.md`, `docs/DECISIONS.md` as the
   durable source of truth — claude-mem is recall on top, not a replacement
4. Use `/loop` for the build loop; use superpowers / Antigravity skills when
   the task matches (brainstorming, debugging, domain skills)

## Manual settings.json (optional)

Same pattern Forge documents for its own plugin. Merge into `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "thedotmack": {
      "source": { "source": "github", "repo": "thedotmack/claude-mem" }
    },
    "antigravity-awesome-skills": {
      "source": {
        "source": "git",
        "url": "https://github.com/sickn33/antigravity-awesome-skills.git"
      }
    }
  },
  "enabledPlugins": {
    "claude-mem@thedotmack": true,
    "superpowers@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "antigravity-awesome-skills@antigravity-awesome-skills": true
  }
}
```

Then restart Claude Code and run the `/plugin install` lines above if anything
is still missing.
