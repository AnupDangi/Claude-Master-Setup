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

## Checklist enforced at REVIEW
- [ ] No hardcoded secrets
- [ ] All input validated; queries parameterized
- [ ] Authorization checked on every sensitive path (no IDOR)
- [ ] No sensitive data in logs/responses
- [ ] New dependencies justified and advisory-clean
