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
for s in setup-loop.sh cancel-loop.sh detect-stack.sh list-local-skills.sh select-skills.sh validate.sh worktree-fanout.sh classify-task.py write-handoff.py sync-project-docs.sh install-default-skills.sh install-skill.sh ensure-skills.sh; do
  [ -f "scripts/$s" ] && ok "runtime $s" || bad "missing runtime $s"
done

[ -f ".claude/statusline.sh" ] && ok "statusline.sh present" || bad "statusline.sh missing"
for d in README.md CLAUDE.md docs/SETUP.md docs/LOOP.md docs/SECURITY.md docs/CHANGELOG.md; do
  [ -f "$d" ] && ok "$d" || bad "missing $d"
done

# Check loop.md contains anti-stall and assigned_agents strings
grep -q "anti-background-install\|never background.*npm\|Never background" .claude/commands/loop.md && ok "loop.md contains anti-background-install rule" || bad "loop.md missing anti-background-install rule"
grep -q "assigned_agents" .claude/commands/loop.md && ok "loop.md contains assigned_agents" || bad "loop.md missing assigned_agents"

for s in scripts/*.sh .claude/hooks/*.sh; do
  bash -n "$s" || bad "shell syntax: $s"
done

python3 - <<'PY' >/dev/null 2>&1 && ok "settings permission rules well-formed" || bad "settings permission rules malformed"
import json
from pathlib import Path
for rule in json.loads(Path(".claude/settings.json").read_text()).get("permissions", {}).get("allow", []):
    if ":*" in rule and not rule.endswith(":*)"):
        raise SystemExit(1)
PY

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

# skills allowlist + discovery
[ -f "templates/skills-allowlist.json" ] && ok "skills allowlist present" || bad "missing skills-allowlist.json"
[ -f "templates/skills-list-snapshot.json" ] && ok "skills list snapshot present" || bad "missing skills-list-snapshot.json"
bash scripts/check-skills-allowlist.sh >/dev/null && ok "allowlist names ⊆ snapshot" || bad "allowlist/snapshot mismatch"
grep -q 'warnDualInstall' bin/cli.js && ok "cli warns on dual install" || bad "cli missing dual-install warn"
grep -q '\.agents' scripts/list-local-skills.sh && ok "list-local-skills scans .agents/skills" || bad "list-local-skills missing .agents scan"
grep -q 'skills-allowlist' scripts/select-skills.sh && ok "select-skills uses allowlist catalog" || bad "select-skills missing catalog"
grep -q 'installDefaultSkills' bin/cli.js && ok "cli installs default skills" || bad "cli missing installDefaultSkills"
grep -q 'MASTER_SKIP_SKILLS' scripts/install-default-skills.sh && ok "skills install has skip escape hatch" || bad "skills install missing skip"
grep -q 'ensure-skills' scripts/setup-loop.sh && ok "setup-loop calls ensure-skills" || bad "setup-loop missing ensure-skills"
MASTER_SKIP_SKILLS=0 bash scripts/install-skill.sh --suggest "react frontend" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d,list)' \
  && ok "install-skill --suggest JSON" || bad "install-skill --suggest failed"
MASTER_SKIP_SKILLS=1 bash scripts/ensure-skills.sh "react frontend ui" 2 | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d,list) and len(d)<=2' \
  && ok "ensure-skills skip mode JSON" || bad "ensure-skills skip mode failed"
MASTER_SKIP_SKILLS=0 bash scripts/install-skill.sh evil/repo --skill "x" >/tmp/master-skill-deny.log 2>&1 || true
grep -qE 'not in skills allowlist|invalid source|suggest' /tmp/master-skill-deny.log \
  && ok "install-skill denies unallowlisted source" || bad "install-skill allowlist gate failed"


# Offline skill install must not fail (npx may fail; script exits 0)
MASTER_SKIP_SKILLS=1 bash scripts/install-default-skills.sh >/dev/null 2>&1 && ok "skills install skip mode" || bad "skills install skip mode failed"

# Discovery: project .agents/skills is indexed and selectable
mkdir -p "$TMP_ROOT/skillproj/.agents/skills/demo-ui-skill" "$TMP_ROOT/skillhome"
cat > "$TMP_ROOT/skillproj/.agents/skills/demo-ui-skill/SKILL.md" <<'SKILL'
---
name: demo-ui-skill
description: Frontend UI design layout CSS for web interfaces
---
# Demo
SKILL
HOME="$TMP_ROOT/skillhome" CLAUDE_PROJECT_DIR="$TMP_ROOT/skillproj" \
  bash scripts/list-local-skills.sh | python3 -c 'import json,sys; d=json.load(sys.stdin); assert any(s["name"]=="demo-ui-skill" and s["source"]=="project" for s in d)' \
  && ok "discovers .agents/skills" || bad "does not discover .agents/skills"
HOME="$TMP_ROOT/skillhome" CLAUDE_PROJECT_DIR="$TMP_ROOT/skillproj" \
  bash scripts/select-skills.sh "improve frontend UI design layout" 3 | python3 -c 'import json,sys; d=json.load(sys.stdin); assert any(s["name"]=="demo-ui-skill" for s in d)' \
  && ok "selects matching .agents skill" || bad "select skills missed .agents skill"

HOME="$TMP_ROOT/home" CLAUDE_PROJECT_DIR="$TMP_ROOT/project" mkdir -p "$TMP_ROOT/home" "$TMP_ROOT/project"
export HOME="$TMP_ROOT/home" CLAUDE_PROJECT_DIR="$TMP_ROOT/project"

# Test 1: start fresh with simple task
bash "$SELF_ROOT/scripts/setup-loop.sh" "fix typo" >/dev/null || bad "setup default"
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" <<'PY' >/dev/null 2>&1 && ok "default max=2 and direct routing" || bad "default loop state"
import json,sys
s=json.load(open(sys.argv[1])); assert s['max_iterations']==2 and s['execution_mode']=='direct' and s['active']
PY

# Prepare steer test: simulate prior validation GREEN so steer must reset
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" <<'PY' >/dev/null 2>&1
import json,sys
s=json.load(open(sys.argv[1]))
s['validation']={
  'status':'green',
  'command':'framework:validate',
  'agent':'validator',
  'checks':['lint'],
  'checked_at':'2020-01-01T00:00:00+00:00',
}
open(sys.argv[1],'w').write(json.dumps(s,indent=2)+'\n')
PY

rm -f "$CLAUDE_PROJECT_DIR/.master/state/validation-pending" >/dev/null 2>&1 || true

# Test 2: steer mode — active loop + second setup-loop preserves iteration and appends correction_log
bash "$SELF_ROOT/scripts/setup-loop.sh" "steer correction" >/dev/null
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" <<'PY' >/dev/null 2>&1 && ok "steer mode preserves iteration and appends correction_log" || bad "steer mode"
import json,sys
s=json.load(open(sys.argv[1]))
assert s.get('iteration') == 1, f"iteration should be 1, got {s.get('iteration')}"
assert s.get('next_action') == 'steer_and_execute', f"next_action should be steer_and_execute"
assert s.get('validation', {}).get('status') == 'pending', f"validation should reset to pending, got {s.get('validation')}"
assert s.get('validation', {}).get('command') is None
assert s.get('validation', {}).get('agent') is None
assert s.get('validation', {}).get('checks') == []
assert s.get('validation', {}).get('checked_at') is None
assert len(s.get('correction_log', [])) >= 1, "correction_log should have an entry"
PY

# Marker file should be re-armed during steer
[ -f "$CLAUDE_PROJECT_DIR/.master/state/validation-pending" ] && ok "steer re-arms validation-pending" || bad "steer missing validation-pending"

# Cancel to reset for fresh complex test
CLAUDE_PROJECT_DIR="$TMP_ROOT/project" bash "$SELF_ROOT/scripts/cancel-loop.sh" >/dev/null 2>&1 || true


# iteration_budget from project.json when --max-iterations omitted
BUDGET_DIR="$TMP_ROOT/budget-proj"
mkdir -p "$BUDGET_DIR/.master/state"
printf '%s\n' '{"schema_version":1,"name":"budget","maturity":"existing","iteration_budget":5,"stack":{},"validate_cmd":"true","allow_no_stack":true,"docs":{"manifest":[],"load_for_loop":false}}' > "$BUDGET_DIR/.master/project.json"
CLAUDE_PROJECT_DIR="$BUDGET_DIR" MASTER_SKIP_SKILLS=1 bash "$SELF_ROOT/scripts/setup-loop.sh" "fix typo" >/dev/null
python3 - "$BUDGET_DIR/.master/state/loop.json" <<'PYBUDGET' >/dev/null 2>&1 && ok "max_iterations from iteration_budget" || bad "iteration_budget ignored"
import json,sys
s=json.load(open(sys.argv[1])); assert s['max_iterations']==5, s.get('max_iterations')
PYBUDGET

# Test 3: complex routing — must start fresh (not steer) so cancel first
bash "$SELF_ROOT/scripts/setup-loop.sh" "implement authentication feature across frontend backend api database with tests and migration for all services" --max-iterations 4 --completion-promise DONE >/dev/null
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" <<'PY' >/dev/null 2>&1 && ok "options, complex routing, skill cap" || bad "adaptive state"
import json,sys
s=json.load(open(sys.argv[1])); assert s['max_iterations']==4 and s['completion_promise']=='DONE'; assert s['execution_mode']=='parallel'; assert len(s['selected_skills'])<=3
# Set state for completion test: validation green, ship completed, assigned_agents (required for parallel)
s['validation']['status']='green'
s['validation']['agent']='validator'
s['ship_completed']=True
s['assigned_agents']=['implementer']
open(sys.argv[1],'w').write(json.dumps(s,indent=2)+'\n')
PY
printf '%s\n' '{"message":{"role":"assistant","content":[{"type":"text","text":"<promise>DONE</promise>"}]}}' > "$TMP_ROOT/transcript.jsonl"
printf '{"transcript_path":"%s"}' "$TMP_ROOT/transcript.jsonl" | bash "$SELF_ROOT/.claude/hooks/loop-stop-hook.sh" >/dev/null
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" "$CLAUDE_PROJECT_DIR/.master/state/handoff.json" <<'PY' >/dev/null 2>&1 && ok "GREEN completion and automatic handoff" || bad "completion/handoff"
import json,sys,os
assert json.load(open(sys.argv[1]))['status']=='completed'; assert os.path.isfile(sys.argv[2])
PY

# Test handoff includes phase field
python3 - "$CLAUDE_PROJECT_DIR/.master/state/handoff.json" <<'PY' >/dev/null 2>&1 && ok "handoff includes phase field" || bad "handoff missing phase field"
import json,sys
h=json.load(open(sys.argv[1]))
assert 'phase' in h, f"phase not in handoff: {list(h.keys())}"
PY

bash "$SELF_ROOT/scripts/setup-loop.sh" "another task" >/dev/null
# Test cancel writes handoff
bash "$SELF_ROOT/scripts/cancel-loop.sh" >/dev/null
python3 - "$CLAUDE_PROJECT_DIR/.master/state/loop.json" "$CLAUDE_PROJECT_DIR/.master/state/handoff.json" <<'PY' >/dev/null 2>&1 && ok "cancel persists cancelled state and writes handoff" || bad "cancel state"
import json,sys,os
s=json.load(open(sys.argv[1])); assert s['status']=='cancelled' and not s['active']
assert os.path.isfile(sys.argv[2]), "handoff.json not written by cancel"
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

python3 - <<'PY' >/dev/null 2>&1 && ok "no stale HARNESS_MAX_/loop.local.md/go refs" || bad "stale HARNESS_MAX_/loop.local.md/go refs"
import re
from pathlib import Path
patterns = [
    re.compile(r"HARNESS_MAX_"),
    re.compile(r"loop\.local\.md"),
    re.compile(r"(^|[^A-Za-z0-9_/])/go\b"),
]
skip_names = {"CHANGELOG.md", "self-check.sh", "test-ship-install.sh"}
skip_dirs = {".git", "node_modules", "test-harness"}
allowed_suffixes = {".md", ".js", ".json", ".sh", ".py", ".yml", ".yaml"}
hits = []
for path in Path(".").rglob("*"):
    if not path.is_file():
        continue
    if any(part in skip_dirs for part in path.parts):
        continue
    if any(part == "worktrees" and "claude" in str(path) for part in path.parts):
        if ".claude" in path.parts and "worktrees" in path.parts:
            continue
    if path.name in skip_names:
        continue
    if path.suffix.lower() not in allowed_suffixes:
        continue
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        continue
    for pat in patterns:
        if pat.search(text):
            hits.append(f"{path}:{pat.pattern}")
            break
raise SystemExit(1 if hits else 0)
PY
if [ "${MASTER_SELF_CHECK_SKIP_VALIDATE:-0}" = 1 ]; then
  ok "full validation skipped inside npm test"
else
  bash scripts/validate.sh >"$TMP_ROOT/validate.log" 2>&1 || true
  grep -q 'GATE: ' "$TMP_ROOT/validate.log" && ok "validation reports verdict" || bad "validation verdict"
fi

echo
[ "$FAIL" -eq 0 ] && echo "Self-check OK" || echo "Self-check failed"
exit "$FAIL"
