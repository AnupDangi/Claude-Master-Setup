#!/usr/bin/env bash
# Verifies the harness itself is wired correctly. Run after install or edits.
# Exit 0 if healthy, 1 if any required piece is missing or malformed.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
FAIL=0
ok()   { printf '  \033[32m✓ %s\033[0m\n' "$1"; }
bad()  { printf '  \033[31m✗ %s\033[0m\n' "$1"; FAIL=1; }

echo "▶ Harness self-check"

# Required agents
for a in orchestrator planner architect implementer implementer-opus validator reviewer security docs-writer mcp-scout evaluator; do
  f=".claude/agents/$a.md"
  if [ -f "$f" ] && head -1 "$f" | grep -q '^---'; then ok "agent: $a"; else bad "agent missing/malformed: $a"; fi
done

# Required commands
for c in loop plan validate review mcp-add bootstrap handoff status ship evaluate; do
  [ -f ".claude/commands/$c.md" ] && ok "command: /$c" || bad "command missing: /$c"
done

# Required hooks
for h in session-start pre-bash-guard protect-paths post-edit-track stop-validate-reminder; do
  [ -f ".claude/hooks/$h.sh" ] && ok "hook: $h" || bad "hook missing: $h"
done

# Required scripts
for s in validate.sh detect-stack.sh install.sh self-check.sh mcp-catalog.json; do
  [ -f "scripts/$s" ] && ok "script: $s" || bad "script missing: $s"
done

# JSON validity
for j in .claude/settings.json scripts/mcp-catalog.json; do
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys; json.load(open('$j'))" 2>/dev/null && ok "valid JSON: $j" || bad "invalid JSON: $j"
  fi
done
# .mcp.json is optional but must be valid if present
if [ -f .mcp.json ] && command -v python3 >/dev/null 2>&1; then
  python3 -c "import json; json.load(open('.mcp.json'))" 2>/dev/null && ok "valid JSON: .mcp.json" || bad "invalid JSON: .mcp.json"
fi

# Core docs
for d in CLAUDE.md docs/LOOP.md docs/AGENTS.md docs/MCP.md docs/SETUP.md; do
  [ -f "$d" ] && ok "doc: $d" || bad "doc missing: $d"
done

# validate.sh runs and reports a gate verdict
if bash scripts/validate.sh >/tmp/harness_selfcheck.log 2>&1 || true; then
  grep -qE "GATE: (GREEN|RED)" /tmp/harness_selfcheck.log && ok "validate.sh reports a gate verdict" || bad "validate.sh did not report a gate verdict"
fi

echo
[ "$FAIL" -eq 0 ] && echo "Harness OK." || echo "Harness has issues — see ✗ above."
exit $FAIL
