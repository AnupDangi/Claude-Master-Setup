# Claude Master Setup

The last Claude Code setup you'll need before starting any project. Clone it, drop in your requirements docs, and let Claude build the engineering foundation for you.

https://github.com/AnupDangi/Claude-Master-Setup

## New to Claude? Start here

Take these three, in order, before anything else. This is the minimum anyone should know before touching this repo:

1. [Claude 101](https://anthropic.skilljar.com/claude-101)
2. [Claude Code 101](https://anthropic.skilljar.com/claude-code-101)
3. [Claude Code in Action](https://anthropic.skilljar.com/claude-code-in-action)

Everything below is optional, for going deeper — MCP servers, agent skills, subagents — if you want to build and deploy your own applications with Claude Code:

4. [Introduction to Model Context Protocol](https://anthropic.skilljar.com/introduction-to-model-context-protocol)
5. [Model Context Protocol: Advanced Topics](https://anthropic.skilljar.com/model-context-protocol-advanced-topics)
6. [Introduction to Agent Skills](https://anthropic.skilljar.com/introduction-to-agent-skills)
7. [Introduction to Subagents](https://anthropic.skilljar.com/introduction-to-subagents)

Also worth a look: [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) — a curated skills list.

## What's inside

- **`MASTER-PROMPT.md`** — a bootstrap prompt that turns a PRD + PTR into a full engineering foundation (architecture, `CLAUDE.md`, `docs/`, roadmap, Git strategy)
- **`.claude/settings.json`** — hooks pre-wired (quality gates, permissions) so Claude behaves correctly out of the box
- **`.claude/context/`** — mode profiles (`dev.md`, `research.md`, `review.md`) that switch how Claude works: building, investigating, or reviewing

No platform, no signup, no config wizard. Just files Claude Code already knows how to read.

## Quick start

### 1. Install

```bash
git clone https://github.com/AnupDangi/Claude-Master-Setup.git my-project
cd my-project
claude
```

Claude Code picks up `.claude/settings.json` automatically — hooks and permissions are live, no setup step needed.

### 2. Bootstrap a new project

Add your own requirement docs to the repo:

```
my-project/
├── PRD.md   # Product Requirements Document
├── PTR.md   # Project Technical Requirements
└── ...
```

Then tell Claude:

```
Read MASTER-PROMPT.md and follow it using PRD.md and PTR.md.
```

Claude reads both documents, asks clarifying questions on anything ambiguous, then generates the full foundation — architecture review, `CLAUDE.md`, complete `docs/` folder, Git/branch strategy, implementation roadmap — before writing any implementation code. Nothing starts until you approve the plan.

## Example: switching modes with skills

The context profiles in `.claude/context/` act as lightweight skills — tell Claude which one to use and it adopts that mode for the task:

```
"Use .claude/context/review.md for this PR."
```
→ Claude reviews thoroughly, ranks issues by severity, and suggests fixes instead of just building.

```
"Use .claude/context/dev.md, implement the login form."
```
→ Claude writes code first, runs tests, keeps commits atomic.

```
"Use .claude/context/research.md, figure out why auth is flaky."
```
→ Claude explores first, documents findings, and holds off on code until the cause is clear.

## Why use this

Every other Claude setup asks you to learn a framework first. This one doesn't:

1. Clone the repo.
2. Give Claude your PRD and PTR.
3. Ask it to read `MASTER-PROMPT.md`.

It does the rest.
