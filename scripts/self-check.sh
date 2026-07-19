#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
SELF_ROOT="$PWD"
FAIL=0
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/master-selfcheck.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
ok() { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✗ %s\n' "$1"; FAIL=1; }
check() { if "$@"; then ok "$*"; else bad "$*"; fi; }

echo "Adaptive loop self-check"

required_commands="bootstrap cancel handoff loop pause status"
actual_commands="$(for f in .claude/commands/*.md; do basename "$f" .md; done | sort | tr '\n' ' ' | sed 's/ $//')"
[ "$actual_commands" = "$required_commands" ] && ok "exactly six commands" || bad "command set: $actual_commands"

for a in architect implementer implementer-opus orchestrator planner reviewer validator; do
  [ -f ".claude/agents/$a.md" ] && ok "agent $a" || bad "missing agent $a"
done
for s in setup-loop.sh cancel-loop.sh detect-stack.sh list-local-skills.sh select-skills.sh validate.sh worktree-fanout.sh classify-task.py write-handoff.py; do
  [ -f "scripts/$s" ] && ok "runtime $s" || bad "missing runtime $s"
done
for d in README.md CLAUDE.md docs/SETUP.md docs/LOOP.md docs/SECURITY.md docs/CHANGELOG.md; do
  [ -f "$d" ] && ok "$d" || bad "missing $d"
done

for s in scripts/*.sh .claude/hooks/*.sh; do
  bash -n "$s" || bad "shell syntax: $s"
done
node --check bin/cli.js >/dev/null 2>&1 && ok "CLI syntax" || bad "CLI syntax"
python3 -m py_compile scripts/classify-task.py scripts/write-handoff.py >/dev/null 2>&1 && ok "Python syntax" || bad "Python syntax"

python3 - <<'PY' >/dev/null 2>&1 && ok "manifest versions and agent paths" || bad "manifest versions and agent paths"
import json
from pathlib import Path
pkg=json.loads(Path('package.json').read_text())
plugin=json.loads(Path('.claude-plugin/plugin.json').read_text())
market=json.loads(Path('.claude-plugin/marketplace.json').read_text())
assert pkg['version']==plugin['version']==market['plugins'][0]['version']
assert all(Path(p.removeprefix('./')).is_file() for p in plugin['agents'])
assert 'skills' not in plugin
PY

HOME="$TMP_ROOT/home" CLAUDE_PROJECT_DIR="$TMP_ROOT/project" mkdir -p "$TMP_ROOT/home" "$TMP_ROOT/project"
export HOME="$TMP_ROOT/home" CLAUDE_PROJECT_DIR="$TMP_ROOT/project"
bash "$SELF_ROOT/scripts/setup-loop.sh" "fix typo" >/dev/null || bad "setup default"
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" <<'PY' >/dev/null 2>&1 && ok "default max=2 and direct routing" || bad "default loop state"
import json,sys
s=json.load(open(sys.argv[1])); assert s['max_iterations']==2 and s['execution_mode']=='direct' and s['active']
PY

bash "$SELF_ROOT/scripts/setup-loop.sh" "implement authentication feature across frontend backend api database with tests and migration for all services" --max-iterations 4 --completion-promise DONE >/dev/null
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" <<'PY' >/dev/null 2>&1 && ok "options, complex routing, skill cap" || bad "adaptive state"
import json,sys
s=json.load(open(sys.argv[1])); assert s['max_iterations']==4 and s['completion_promise']=='DONE'; assert s['execution_mode']=='parallel'; assert len(s['selected_skills'])<=3
s['validation']['status']='green'; open(sys.argv[1],'w').write(json.dumps(s,indent=2)+'\n')
PY
printf '%s\n' '{"message":{"role":"assistant","content":[{"type":"text","text":"<promise>DONE</promise>"}]}}' > "$TMP_ROOT/transcript.jsonl"
printf '{"transcript_path":"%s"}' "$TMP_ROOT/transcript.jsonl" | bash "$SELF_ROOT/.claude/hooks/loop-stop-hook.sh" >/dev/null
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" "$CLAUDE_PROJECT_DIR/.master/state/handoff.json" <<'PY' >/dev/null 2>&1 && ok "GREEN completion and automatic handoff" || bad "completion/handoff"
import json,sys,os
assert json.load(open(sys.argv[1]))['status']=='completed'; assert os.path.isfile(sys.argv[2])
PY

bash "$SELF_ROOT/scripts/setup-loop.sh" "another task" >/dev/null
bash "$SELF_ROOT/scripts/cancel-loop.sh" >/dev/null
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" <<'PY' >/dev/null 2>&1 && ok "cancel persists cancelled state" || bad "cancel state"
import json,sys
s=json.load(open(sys.argv[1])); assert s['status']=='cancelled' and not s['active']
PY

printf '{bad json' > "$CLAUDE_PROJECT_DIR/.master/state/loop.json"
printf '{}' | bash "$SELF_ROOT/.claude/hooks/loop-stop-hook.sh" >/dev/null 2>&1
[ ! -f "$CLAUDE_PROJECT_DIR/.master/state/loop.json" ] && ok "corrupt state stops safely" || bad "corrupt state not removed"

bash "$SELF_ROOT/scripts/setup-loop.sh" "missing transcript check" >/dev/null
printf '{}' | bash "$SELF_ROOT/.claude/hooks/loop-stop-hook.sh" >/dev/null 2>&1
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" <<'PY' >/dev/null 2>&1 && ok "missing transcript stops safely" || bad "missing transcript state"
import json,sys
s=json.load(open(sys.argv[1])); assert s['status']=='error' and not s['active']
PY

[ "$(python3 "$SELF_ROOT/scripts/classify-task.py" 'fix typo' | python3 -c 'import json,sys; print(json.load(sys.stdin)["execution_mode"])')" = direct ] && ok "direct classifier" || bad "direct classifier"
[ "$(python3 "$SELF_ROOT/scripts/classify-task.py" 'implement authentication feature' | python3 -c 'import json,sys; print(json.load(sys.stdin)["execution_mode"])')" = delegated ] && ok "delegated classifier" || bad "delegated classifier"

cd "$SELF_ROOT" || exit 1
bash scripts/worktree-fanout.sh --help 2>&1 | grep -q 'create|status|merge|cleanup' && ok "fanout help" || bad "fanout help"
if printf '%s\n' '{"slices":[{"id":"../x","branch":"fanout/a","files":["a.ts"]}]}' > "$TMP_ROOT/bad.json" && ! bash scripts/worktree-fanout.sh status "$TMP_ROOT/bad.json" >/dev/null 2>&1; then ok "fanout rejects unsafe id"; else bad "fanout unsafe id"; fi

if command -v rg >/dev/null 2>&1; then
  for pattern in 'HARNESS_MAX_' 'loop.local.md' '/go'; do
    if rg -n "$pattern" --glob '!docs/CHANGELOG.md' --glob '!scripts/self-check.sh' . >/dev/null 2>&1; then bad "stale reference: $pattern"; else ok "no stale $pattern"; fi
  done
else
  bad "ripgrep required for stale-reference checks"
fi

if [ "${MASTER_SELF_CHECK_SKIP_VALIDATE:-0}" = 1 ]; then
  ok "full validation skipped inside npm test"
else
  bash scripts/validate.sh >"$TMP_ROOT/validate.log" 2>&1 || true
  grep -q 'GATE: ' "$TMP_ROOT/validate.log" && ok "validation reports verdict" || bad "validation verdict"
fi

echo
[ "$FAIL" -eq 0 ] && echo "Self-check OK" || echo "Self-check failed"
exit "$FAIL"
