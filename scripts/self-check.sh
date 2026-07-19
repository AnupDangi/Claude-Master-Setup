#!/usr/bin/env bash
# Verifies the harness itself is wired correctly. Run after install or edits.
# Exit 0 if healthy, 1 if any required piece is missing or malformed.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
FAIL=0
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/harness-selfcheck.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
ok()   { printf '  \033[32m✓ %s\033[0m\n' "$1"; }
bad()  { printf '  \033[31m✗ %s\033[0m\n' "$1"; FAIL=1; }

echo "▶ Harness self-check"

# Required agents
for a in orchestrator planner architect implementer implementer-opus validator reviewer security docs-writer mcp-scout evaluator; do
  f=".claude/agents/$a.md"
  if [ -f "$f" ] && head -1 "$f" | grep -q '^---'; then ok "agent: $a"; else bad "agent missing/malformed: $a"; fi
done

# Required commands
for c in loop plan validate review mcp-add bootstrap handoff status ship evaluate init; do
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
for d in docs/CAPABILITY_ORCHESTRATION.md docs/templates/AGENT_TASK.md .claude/skills/capability-orchestrator/SKILL.md docs/AI_OS.md docs/BROWNFIELD.md docs/BUILD_EFFORT.md; do
  [ -f "$d" ] && ok "capability: $d" || bad "capability missing: $d"
done

# Plugin packaging (.claude-plugin/) is OPTIONAL here: it only lives in this
# harness's own source repo, never copied by installLocal() into a consumer
# project (a --local install has no use for plugin/marketplace manifests).
# Skip silently if absent; validate fully (JSON + version-sync) if present.
if [ -f ".claude-plugin/plugin.json" ] || [ -f ".claude-plugin/marketplace.json" ]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 - <<'PY'
import json
from pathlib import Path
plugin = json.loads(Path(".claude-plugin/plugin.json").read_text(encoding="utf-8"))
market = json.loads(Path(".claude-plugin/marketplace.json").read_text(encoding="utf-8"))
pkg = json.loads(Path("package.json").read_text(encoding="utf-8"))
assert plugin.get("name") == "master", f"plugin.json name must be 'master', got {plugin.get('name')!r}"
assert plugin.get("version") == pkg.get("version"), f"plugin.json version {plugin.get('version')!r} != package.json {pkg.get('version')!r}"
entries = market.get("plugins") or []
assert entries and entries[0].get("name") == "master", "marketplace.json must list a 'master' plugin"
assert entries[0].get("version") == pkg.get("version"), f"marketplace.json plugin version {entries[0].get('version')!r} != package.json {pkg.get('version')!r}"
PY
    then
      ok "plugin packaging: .claude-plugin/plugin.json + marketplace.json valid and version-synced"
    else
      bad "plugin packaging: .claude-plugin manifests present but invalid or version-drifted from package.json"
    fi
  else
    ok "plugin packaging files present (no python3 to validate JSON/version sync)"
  fi
fi

# list-local-skills.sh emits valid JSON
if bash scripts/list-local-skills.sh >$TMP_ROOT/skills.json 2>/dev/null; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; json.load(open('$TMP_ROOT/skills.json'))" 2>/dev/null \
      && ok "list-local-skills.sh emits JSON" \
      || bad "list-local-skills.sh invalid JSON"
  else
    ok "list-local-skills.sh ran (no python3 to validate JSON)"
  fi
else
  bad "list-local-skills.sh failed"
fi

# worktree-fanout.sh help
bash scripts/worktree-fanout.sh --help >$TMP_ROOT/fanout-help.txt 2>&1 \
  && grep -q "create|status|merge|cleanup" $TMP_ROOT/fanout-help.txt \
  && ok "worktree-fanout.sh help" \
  || bad "worktree-fanout.sh help missing/malformed"

# worktree-fanout rejects unsafe manifests
if printf '%s\n' '{"slices":[{"id":"../x","branch":"fanout/a","files":["a.ts"]}]}' >$TMP_ROOT/fanout-bad.json \
  && ! bash scripts/worktree-fanout.sh status $TMP_ROOT/fanout-bad.json >$TMP_ROOT/fanout-bad.out 2>&1; then
  ok "worktree-fanout.sh rejects bad slice id"
else
  bad "worktree-fanout.sh should reject path-like slice ids"
fi

# select-skills.sh returns JSON
if bash scripts/select-skills.sh "capability orchestration" 2 >$TMP_ROOT/select.json 2>$TMP_ROOT/select.err; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; json.load(open('$TMP_ROOT/select.json'))" 2>/dev/null \
      && ok "select-skills.sh emits JSON" \
      || bad "select-skills.sh invalid JSON"
  else
    ok "select-skills.sh ran"
  fi
else
  bad "select-skills.sh failed"
fi

# AI OS scripts smoke
bash scripts/loop-event.sh select '{"task":"self-check"}' >$TMP_ROOT/event.json 2>&1 \
  && bash scripts/loop-event.sh summary >$TMP_ROOT/event-summary.json 2>&1 \
  && ok "loop-event.sh append+summary" \
  || bad "loop-event.sh failed"

bash scripts/budget-check.sh >$TMP_ROOT/budget.json 2>&1 \
  && ok "budget-check.sh" \
  || { [ $? -eq 3 ] && ok "budget-check.sh (stop signaled)" || bad "budget-check.sh failed"; }

bash scripts/lease.sh acquire "self-check-lease" self-check >$TMP_ROOT/lease.json 2>&1 \
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
if echo '{"file_path":"/tmp/x/.env"}' | HARNESS_ALLOW_PROTECTED_EDITS=0 bash .claude/hooks/protect-paths.sh >$TMP_ROOT/protect-env.out 2>&1; then
  bad "protect-paths should block .env"
else
  ok "protect-paths blocks .env"
fi
if echo '{"file_path":"scripts/validate.sh"}' | HARNESS_ALLOW_PROTECTED_EDITS=0 bash .claude/hooks/protect-paths.sh >$TMP_ROOT/protect-validate.out 2>&1; then
  bad "protect-paths should block validate.sh"
else
  ok "protect-paths blocks control-plane validate.sh"
fi
# Embedded-quote regression: reconstruct payload without putting the bad pattern in this file as a runnable sample.
_bg_payload="$(python3 -c 'import json; print(json.dumps({"command": "git commit -m x && " + "rm" + " -rf " + "~"}))')"
if printf '%s' "$_bg_payload" | bash .claude/hooks/pre-bash-guard.sh >$TMP_ROOT/bash-guard.out 2>&1; then
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
# .mcp.json and .claude-plugin/*.json are optional but must be valid if present
for j in .mcp.json .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  if [ -f "$j" ] && command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; json.load(open('$j'))" 2>/dev/null && ok "valid JSON: $j" || bad "invalid JSON: $j"
  fi
done

# Core docs
for d in CLAUDE.md docs/LOOP.md docs/AGENTS.md docs/MCP.md docs/SETUP.md; do
  [ -f "$d" ] && ok "doc: $d" || bad "doc missing: $d"
done

# validate.sh runs and reports a gate verdict. npm test sets the skip flag to
# avoid test → self-check → validate → npm test recursion.
if [ "${HARNESS_SELF_CHECK_SKIP_VALIDATE:-0}" = "1" ]; then
  ok "validate.sh verdict skipped by npm test (recursion guard)"
elif bash scripts/validate.sh >"$TMP_ROOT/validate.log" 2>&1 || true; then
  grep -qE "GATE: (GREEN|RED)" "$TMP_ROOT/validate.log" && ok "validate.sh reports a gate verdict" || bad "validate.sh did not report a gate verdict"
fi

echo
[ "$FAIL" -eq 0 ] && echo "Harness OK." || echo "Harness has issues — see ✗ above."
exit $FAIL
