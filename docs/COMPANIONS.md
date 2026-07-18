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

## Auto-complete (recommended)

`npx claude-master-setup --global` (and `--local`) will, by default:

1. Merge marketplaces + `enabledPlugins` into `~/.claude/settings.json`
2. Run the **non-interactive** Claude Code CLI (same as `/plugin …` but scriptable):

```bash
claude plugin marketplace add thedotmack/claude-mem
claude plugin install claude-mem@thedotmack --scope user

claude plugin install superpowers@claude-plugins-official --scope user
claude plugin install code-review@claude-plugins-official --scope user

claude plugin marketplace add sickn33/antigravity-awesome-skills
claude plugin install antigravity-awesome-skills@antigravity-awesome-skills --scope user
```

Requires `claude` on your `PATH`. Skip with:

```bash
npx claude-master-setup --global --skip-companions
```

Force again later:

```bash
npx claude-master-setup --global --with-companions
```

Then **restart Claude Code** so plugins load. Per repo: `/learn-codebase` once (claude-mem).

### Why settings.json alone is not enough

| Layer | What it does |
|---|---|
| `extraKnownMarketplaces` + `enabledPlugins` in settings.json | Registers catalogs + marks plugins enabled |
| `claude plugin marketplace add` | Clones the marketplace catalog locally |
| `claude plugin install …` | Downloads plugin files into `~/.claude/plugins/cache/` |

Forge documents Option B (settings merge). We do that **and** call the CLI so a
new user does not have to type six `/plugin` lines by hand.

## Manual (inside Claude Code TUI)

If the CLI path fails:

```text
/plugin marketplace add thedotmack/claude-mem
/plugin install claude-mem@thedotmack

/plugin install superpowers@claude-plugins-official
/plugin install code-review@claude-plugins-official

/plugin marketplace add sickn33/antigravity-awesome-skills
/plugin install antigravity-awesome-skills
```

## Pairing with the harness

1. `/bootstrap` (or open an existing repo)
2. `/learn-codebase` once (claude-mem) so later sessions have repo context
3. Keep `docs/PROJECT_STATE.md`, `docs/SESSION.md`, `docs/DECISIONS.md` as the
   durable source of truth — claude-mem is recall on top, not a replacement
4. Use `/loop` for the build loop; use superpowers / Antigravity skills when
   the task matches

## Enhance further (roadmap ideas)

| Enhancement | Why |
|---|---|
| Ship **this harness as a marketplace plugin** (`.claude-plugin/`) | One `/plugin install claude-master-setup@…` like Forge Option B |
| `--companions=minimal\|full` | Minimal = claude-mem + superpowers only |
| Verify step | `claude plugin list` after install; print missing plugins |
| Project-scope companions | `claude plugin install … --scope project` for team lockfiles |
| Post-install `/learn-codebase` hint only when claude-mem succeeded | Cleaner UX |
