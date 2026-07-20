---
description: Inspect this repository once and create minimal project-specific context
argument-hint: "[optional product vision / constraints]"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(test:*), Bash(git status:*), Bash(bash */scripts/detect-stack.sh:*), Bash(bash */scripts/ensure-skills.sh:*), Bash(bash */scripts/install-skill.sh:*), Bash(npx:*)
model: sonnet
---

# Bootstrap

User intent (optional): $ARGUMENTS

## Role

You prepare **minimal project memory** so later `/loop` sessions can work from files, not chat. You do not implement features.

## Memory you create (and nothing else)

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Mission, stack, run/verify, conventions — ≤40 lines, **zero** harness prose |
| `.master/project.json` | Facts, maturity, `validate_cmd`, `iteration_budget`, docs flags |
| `.master/state/loop.json` | Idle loop state if missing |
| `.master/docs/ROADMAP.md` | Optional ≤4 evidence-backed outcomes |
| `.master/docs/DESIGN.md` | Only if UI/visual product (args or evidence) |
| `.master/docs/DECISIONS.md` | Stub for greenfield architecture ADRs |

## Generate, do not copy

Write each doc from repository evidence. Peek at
`${CLAUDE_PLUGIN_ROOT}/templates/master-docs/` for section headings only.
Never `cp` / paste those templates into `.master/docs/`. Empty headings +
one evidence-backed sentence beat a copied stub.

## Read before write

Follow `${CLAUDE_PLUGIN_ROOT}/MASTER-PROMPT.md` (repo-first rules). Repository evidence beats `$ARGUMENTS`. Command spelling: `/bootstrap` (not `/boostrap`).

## Rules

- Never invent facts that contradict README/manifests/source
- Never paste agents, loop internals, or harness manuals into `CLAUDE.md`
- Do **not** create API/DATABASE/SECURITY/TESTING/DEPLOYMENT at bootstrap (SHIP phase later)
- Do **not** copy `templates/master-docs/*` into the project
- `iteration_budget`: new/prototype → 3; existing → 5; production → 7 (this becomes default `/loop` max unless `--max-iterations` is passed)
- **Visual product gate:** If the project has UI/visual evidence (React, Vue, Svelte, mobile UI, design system, Tailwind, etc.) you **must** create `.master/docs/DESIGN.md` before finishing bootstrap. Do not end bootstrap without it for a visual product — its absence will block BUILD in subsequent loops.
- **`runtime_check`:** Set in `.master/project.json` only when an obvious smoke command exists (e.g. `curl -sf http://localhost:3000/health`). Leave `null` when uncertain — never invent a fragile check.

## Skills (optional, best-effort)

If stack/args clearly need UI/React/deploy/docs skills:

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/ensure-skills.sh "<short summary>" 3`

Failures are non-fatal. Off-allowlist → suggest `npx skills add owner/repo --skill "Name" -g -a claude-code -y --copy`.

## Done when

Report what was inferred, then suggest one concrete first slice:

`/loop "<smallest shippable behaviour>"`

(Iterations default from `iteration_budget` in project.json.)
