# Security

> The security subagent reviews against this. Fill in on bootstrap; keep current.

## Threat model (brief)
_(who might attack, what they'd want, the highest-value assets to protect)_

## Authentication & authorization
_(how identity is established and how access is enforced; roles/permissions)_

## Secrets management
- All secrets in env vars; `.env` gitignored; `.env.example` documents names.
- MCP servers reference `${ENV_VAR}` only — never literals in `.mcp.json`.
- No secret in source, logs, or API responses.

## Input handling
_(validation/sanitization policy; parameterized queries; output encoding)_

## Data protection
_(encryption in transit/at rest where required; PII handling; retention)_

## Dependencies
_(how new deps are vetted; advisory scanning; pinned versions)_

## Harness / Claude Code permissions (AI OS model)

This harness is meant to be an **AI OS for building software**. Control plane
priority (highest first):

1. **Harness gates** — GATE 1 / VALIDATE / GATE 2 / `max-iterations=1` + budget stop
2. **Hooks + deny/ask lists** — `pre-bash-guard`; `protect-paths.sh` **blocks**
   (exit 2) edits to `.env` / lockfiles / CI unless `HARNESS_ALLOW_PROTECTED_EDITS=1`
3. **Claude Code permission mode** — reduces click fatigue; does **not** replace (1)/(2)

| Mode | File edits | Bash | Use for AI OS? |
|---|---|---|---|
| `default` | Prompt | Prompt | Safer first day / shared/prod-secrets repos |
| **`acceptEdits` (shipped default)** | Auto in cwd | Still prompts (unless allowlisted) | **Yes — recommended project default** with iteration budget + gates |
| `auto` | Classifier | Classifier | **Best for long autonomous sessions** — set in **user** `~/.claude/settings.json` only (Claude Code ignores `auto` in project settings) |
| `bypassPermissions` | Everything | Everything | **No** as project default — disposable VMs/CI only |
| `plan` / `dontAsk` | Restricted | Restricted | Exploration / locked CI |

**Shipped:** `"defaultMode": "acceptEdits"` plus broad `allow` for engineering tools,
`ask` for `git push` / `WebFetch` / `docker` / `gh`, `deny` for secrets/`sudo`.

**Why acceptEdits is fine for AI OS:** the dangerous failure mode in Flappy Bird
was unbounded `/loop` + skipped human gates — not edit auto-accept. With
`HARNESS_MAX_ITERATIONS_PER_RUN=1` and non-skippable GATE 1/2, `acceptEdits`
removes prompt fatigue without granting “finish the whole roadmap unsupervised.”

**Auto mode:** enable yourself in `~/.claude/settings.json` when your account
supports it (`"defaultMode": "auto"`). Prefer auto over `bypassPermissions` for
long BUILD sessions — it still background-checks destructive actions.

**Never put API keys or PATs** in agent prompts, `settings.json`, or committed docs.

## Honest limits (control-plane integrity)

Hooks and permission lists are **defense-in-depth for same-user agents**, not a
sandbox against a determined process with your UID.

1. **`allow` is UX, not confinement.** Broad `Bash(python3:*)` / `Bash(node:*)`
   can sidestep `ask`/`deny` (e.g. read secrets via an interpreter). Prefer a VM for
   untrusted prompts; do not treat deny lists as a security boundary.
2. **Control-plane files are blocked by default** — `.claude/hooks/**`,
   `.claude/settings.json`, `.claude/agents/**`, `.claude/commands/**`, and key
   `scripts/` gates (`validate.sh`, budget/lease/event helpers). Override only with
   `HARNESS_ALLOW_PROTECTED_EDITS=1` (visible).
3. **Budget / leases / event log** are cooperative (gitignored). They slow session
   burn; they are not cryptographic enforcement.
4. **Real guarantees** remain human GATE 1/2, binary VALIDATE, REVIEW + SECURITY
   every iteration, and not shipping `bypassPermissions`.

## Checklist enforced at REVIEW
- [ ] No hardcoded secrets
- [ ] All input validated; queries parameterized
- [ ] Authorization checked on every sensitive path (no IDOR)
- [ ] No sensitive data in logs/responses
- [ ] New dependencies justified and advisory-clean
- [ ] Project `defaultMode` is not silently set to bypass-all permissions
