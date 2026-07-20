---
description: Inspect this repository once and create minimal project-specific context
argument-hint: "[optional product vision / constraints]"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(test:*), Bash(git status:*), Bash(bash */scripts/detect-stack.sh:*), Bash(bash */scripts/ensure-skills.sh:*), Bash(bash */scripts/install-skill.sh:*), Bash(npx:*)
model: sonnet
---

# Bootstrap

User intent (optional): $ARGUMENTS

Read `${CLAUDE_PLUGIN_ROOT}/MASTER-PROMPT.md`, then inspect the repository before
writing anything. The repository is the primary source of truth.

**Note**: The command is spelled `/bootstrap` — not `/boostrap` (common typo).

If `$ARGUMENTS` is non-empty (product vision, constraints, stack preferences):
treat it as a **supplement** for greenfield / empty repos and for roadmap outcomes.
Never invent repo facts that contradict README, manifests, or source. Do not start
feature implementation in bootstrap.

Create or refine only:

- `CLAUDE.md` — this project's mission, stack, run/verify commands, conventions
- `.master/project.json` — structured facts and maturity; include `docs.manifest` and `docs.load_for_loop` when the project has maturity `existing` or `production`
- `.master/state/loop.json` — idle state if missing
- optional `.master/docs/ROADMAP.md` — at most four evidence-backed outcomes
  (ground in repo + `$ARGUMENTS` when present)
- For visual/UI products (`$ARGUMENTS` mentions design, UI, frontend, web app):
  create `.master/docs/DESIGN.md` stub (colors, fonts, layout intent)
- For greenfield projects, create `.master/docs/DECISIONS.md` stub for architecture decisions

Never paste harness instructions, agent rosters, loop internals, or generic
architecture into the project's `CLAUDE.md`. Do not implement feature code.

Progressive docs: do NOT generate API.md, DATABASE.md, SECURITY.md, TESTING.md,
or DEPLOYMENT.md during bootstrap. Those are added progressively at SHIP phase.

Set `iteration_budget` in `.master/project.json` based on project complexity:
- new/prototype: 3 iterations
- existing: 5 iterations
- production: 7 iterations

After writing project files, if the stack or `$ARGUMENTS` clearly need curated
skills (UI/React/deploy/docs), run once:

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/ensure-skills.sh "<short stack or vision summary>" 3`

Failures are non-fatal. For skills outside the allowlist, suggest the user run
`npx skills add owner/repo --skill "Name" -g -a claude-code -y --copy` rather than
auto-installing untrusted sources.

Finish by suggesting a concrete first `/loop "..."` (default two iterations).
If `$ARGUMENTS` described a product, the first loop task should be the smallest
shippable slice of that vision.
