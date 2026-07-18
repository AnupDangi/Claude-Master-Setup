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
for s in validate.sh detect-stack.sh install.sh self-check.sh mcp-catalog.json list-local-skills.sh worktree-fanout.sh select-skills.sh loop-event.sh lease.sh budget-check.sh write-scorecard.sh estimate-build-effort.sh; do
  [ -f "scripts/$s" ] && ok "script: $s" || bad "script missing: $s"
done

# Capability orchestration docs + template + companion skill + AI OS
for d in docs/CAPABILITY_ORCHESTRATION.md docs/templates/AGENT_TASK.md .claude/skills/capability-orchestrator/SKILL.md docs/AI_OS.md docs/BROWNFIELD.md docs/BUILD_EFFORT.md .github/workflows/harness-ci.yml; do
  [ -f "$d" ] && ok "capability: $d" || bad "capability missing: $d"
done

# list-local-skills.sh emits valid JSON
if bash scripts/list-local-skills.sh >/tmp/harness_skills.json 2>/dev/null; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; json.load(open('/tmp/harness_skills.json'))" 2>/dev/null \
      && ok "list-local-skills.sh emits JSON" \
      || bad "list-local-skills.sh invalid JSON"
  else
    ok "list-local-skills.sh ran (no python3 to validate JSON)"
  fi
else
  bad "list-local-skills.sh failed"
fi

# worktree-fanout.sh help
bash scripts/worktree-fanout.sh --help >/tmp/harness_fanout_help.txt 2>&1 \
  && grep -q "create|status|merge|cleanup" /tmp/harness_fanout_help.txt \
  && ok "worktree-fanout.sh help" \
  || bad "worktree-fanout.sh help missing/malformed"

# worktree-fanout rejects unsafe manifests
if printf '%s\n' '{"slices":[{"id":"../x","branch":"fanout/a","files":["a.ts"]}]}' >/tmp/harness_fanout_bad.json \
  && ! bash scripts/worktree-fanout.sh status /tmp/harness_fanout_bad.json >/tmp/harness_fanout_bad.out 2>&1; then
  ok "worktree-fanout.sh rejects bad slice id"
else
  bad "worktree-fanout.sh should reject path-like slice ids"
fi

# select-skills.sh returns JSON
if bash scripts/select-skills.sh "capability orchestration" 2 >/tmp/harness_select.json 2>/tmp/harness_select.err; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; json.load(open('/tmp/harness_select.json'))" 2>/dev/null \
      && ok "select-skills.sh emits JSON" \
      || bad "select-skills.sh invalid JSON"
  else
    ok "select-skills.sh ran"
  fi
else
  bad "select-skills.sh failed"
fi

# AI OS scripts smoke
bash scripts/loop-event.sh select '{"task":"self-check"}' >/tmp/harness_event.json 2>&1 \
  && bash scripts/loop-event.sh summary >/tmp/harness_event_sum.json 2>&1 \
  && ok "loop-event.sh append+summary" \
  || bad "loop-event.sh failed"

bash scripts/budget-check.sh >/tmp/harness_budget.json 2>&1 \
  && ok "budget-check.sh" \
  || { [ $? -eq 3 ] && ok "budget-check.sh (stop signaled)" || bad "budget-check.sh failed"; }

bash scripts/lease.sh acquire "self-check-lease" self-check >/tmp/harness_lease.json 2>&1 \
  && bash scripts/lease.sh release "self-check-lease" self-check >/dev/null 2>&1 \
  && ok "lease.sh acquire+release" \
  || bad "lease.sh failed"

# build-effort estimator: generic vs hard intents
if command -v python3 >/dev/null 2>&1; then
  fast_tier="$(bash scripts/estimate-build-effort.sh /dev/null /dev/null "build a simple todo cli app" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('tier',''))" 2>/dev/null || true)"
  hard_tier="$(bash scripts/estimate-build-effort.sh /dev/null /dev/null "build a gta vice city game clone and productionize train an llm" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('tier',''))" 2>/dev/null || true)"
  if [ "$fast_tier" = "fast" ] || [ "$fast_tier" = "standard" ]; then
    ok "estimate-build-effort: simple todo → $fast_tier"
  else
    bad "estimate-build-effort: expected fast/standard for todo cli (got: $fast_tier)"
  fi
  if [ "$hard_tier" = "rigorous" ]; then
    ok "estimate-build-effort: game+llm → rigorous"
  else
    bad "estimate-build-effort: expected rigorous for game+llm (got: $hard_tier)"
  fi
fi

# protect-paths blocks .env (force override off — user env may have it set)
if echo '{"file_path":"/tmp/x/.env"}' | HARNESS_ALLOW_PROTECTED_EDITS=0 bash .claude/hooks/protect-paths.sh >/tmp/pp.out 2>&1; then
  bad "protect-paths should block .env"
else
  ok "protect-paths blocks .env"
fi
if echo '{"file_path":"scripts/validate.sh"}' | HARNESS_ALLOW_PROTECTED_EDITS=0 bash .claude/hooks/protect-paths.sh >/tmp/pp2.out 2>&1; then
  bad "protect-paths should block validate.sh"
else
  ok "protect-paths blocks control-plane validate.sh"
fi
# Embedded-quote regression: reconstruct payload without putting the bad pattern in this file as a runnable sample.
_bg_payload="$(python3 -c 'import json; print(json.dumps({"command": "git commit -m x && " + "rm" + " -rf " + "~"}))')"
if printf '%s' "$_bg_payload" | bash .claude/hooks/pre-bash-guard.sh >/tmp/bg.out 2>&1; then
  bad "pre-bash-guard should block home wipe with embedded quotes"
else
  ok "pre-bash-guard blocks dangerous cmd with embedded quotes"
fi

# JSON validity
# Statusline: user-level only (project settings must not wire CLAUDE_PROJECT_DIR statusline)
if command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY'
import json
from pathlib import Path
p = Path(".claude/settings.json")
s = json.loads(p.read_text(encoding="utf-8"))
cmd = (s.get("statusLine") or {}).get("command") or ""
if "statusline" in cmd and "CLAUDE_PROJECT_DIR" in cmd:
    raise SystemExit(1)
PY
  then
    ok "project settings: no project-path statusLine"
  else
    bad "project settings must not wire \$CLAUDE_PROJECT_DIR statusline"
  fi
  fake_root="$(mktemp -d "${TMPDIR:-/tmp}/harness-statusline.XXXXXX")"
  mkdir -p "$fake_root/nested"
  sample='{"model":{"display_name":"Test"},"workspace":{"current_dir":"'"$fake_root"'/nested"},"context_window":{"used_percentage":10}}'
  out="$(printf '%s' "$sample" | CLAUDE_PROJECT_DIR="$fake_root" python3 .claude/statusline.sh 2>/dev/null || true)"
  expect_name="$(basename "$fake_root")"
  case "$out" in
    *"📁 ${expect_name}"*) ok "statusline uses CLAUDE_PROJECT_DIR root" ;;
    *) bad "statusline should show project root from CLAUDE_PROJECT_DIR (got: $out)" ;;
  esac
  rm -rf "$fake_root"
fi

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
