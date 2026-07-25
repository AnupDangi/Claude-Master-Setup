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

# Phase C: agent files must contain required section headers and anti-stall keyword
for a in implementer implementer-opus orchestrator planner reviewer validator; do
  f=".claude/agents/$a.md"
  [ -f "$f" ] || continue
  grep -q "^## Role" "$f" && ok "agent $a has ## Role" || bad "agent $a missing ## Role"
  grep -qE "^## Return exactly|^## Return$|^## Output" "$f" && ok "agent $a has return schema" || bad "agent $a missing return schema (## Return exactly / ## Return / ## Output)"
  grep -qi "anti.stall\|stall\|never background\|foreground" "$f" && ok "agent $a has anti-stall" || bad "agent $a missing anti-stall"
done
for s in setup-loop.sh cancel-loop.sh detect-stack.sh list-local-skills.sh select-skills.sh validate.sh worktree-fanout.sh classify-task.py write-handoff.py sync-project-docs.sh install-default-skills.sh install-skill.sh ensure-skills.sh append-loop-event.py query-events.py; do
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
python3 -m py_compile scripts/classify-task.py scripts/write-handoff.py scripts/append-loop-event.py scripts/query-events.py >/dev/null 2>&1 && ok "Python syntax" || bad "Python syntax"

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
grep -q 'disableMasterPluginInSettings' bin/cli.js && ok "cli enforces single path" || bad "cli missing single-path enforce"
grep -q 'isMasterOwnedHookEntry' bin/cli.js && ok "cli detects legacy master hooks" || bad "cli missing legacy hook detect"
node bin/cli.js --help 2>&1 | grep -q -- '--doctor' && ok "cli help lists --doctor" || bad "cli help missing --doctor"
node bin/cli.js --help 2>&1 | grep -q -- '--repair' && ok "cli help lists --repair" || bad "cli help missing --repair"
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

# Phase E: verify loop_start event written by setup-loop
python3 - "$CLAUDE_PROJECT_DIR/.master/state/history/events.jsonl" <<'PY' >/dev/null 2>&1 && ok "loop_start event written" || bad "missing loop_start event"
import json,sys
from pathlib import Path
lines=[l for l in Path(sys.argv[1]).read_text().splitlines() if l.strip()]
events=[json.loads(l) for l in lines]
assert any(e.get('type')=='loop_start' for e in events),f'no loop_start in {events}'
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
# Gate 2.5 (Phase C): write AGENT_TASK.md with ## Objective for delegated/parallel completion
printf '## Objective\nPhase C golden-loop test completion.\n' > "$CLAUDE_PROJECT_DIR/AGENT_TASK.md"
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
python3 "$SELF_ROOT/scripts/classify-task.py" 'implement authentication feature' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get("routing_reason","")!="", "routing_reason must be non-empty for delegated"' >/dev/null 2>&1 && ok "delegated routing_reason non-empty" || bad "delegated routing_reason missing"
[ "$(python3 "$SELF_ROOT/scripts/classify-task.py" 'implement authentication feature across frontend backend api database with tests and migration' | python3 -c 'import json,sys; print(json.load(sys.stdin)["execution_mode"])')" = parallel ] && ok "parallel classifier" || bad "parallel classifier"
python3 "$SELF_ROOT/scripts/classify-task.py" 'fix typo' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "routing_reason" in d, "routing_reason key missing from classifier output"' >/dev/null 2>&1 && ok "classifier output has routing_reason key" || bad "classifier missing routing_reason key"

# require-agents-before-edit PreToolUse gate
GATE_HOOK="$SELF_ROOT/.claude/hooks/require-agents-before-edit.sh"
[ -f "$GATE_HOOK" ] && ok "require-agents-before-edit.sh present" || bad "missing require-agents-before-edit.sh"
grep -q 'harness:require-agents-before-edit' .claude/settings.json && ok "settings wires require-agents-before-edit" || bad "settings missing require-agents gate"
grep -q 'harness:require-agents-before-edit' .claude-plugin/plugin.json && ok "plugin wires require-agents-before-edit" || bad "plugin missing require-agents gate"
grep -q "require-agents-before-edit" bin/cli.js && ok "cli wires require-agents-before-edit" || bad "cli missing require-agents gate"
[ -f ".claude/hooks/notify-stop.sh" ] && ok "notify-stop.sh present" || bad "missing notify-stop.sh"
grep -q 'harness:notify-stop' .claude/settings.json && ok "settings wires notify-stop" || bad "settings missing notify-stop"
grep -q 'harness:notify-stop' .claude-plugin/plugin.json && ok "plugin wires notify-stop" || bad "plugin missing notify-stop"
grep -q 'notify-stop' bin/cli.js && ok "cli wires notify-stop" || bad "cli missing notify-stop"
grep -q 'loop.json' .claude/statusline.sh && ok "statusline reads loop.json" || bad "statusline missing loop awareness"
grep -q 'attempt_id' scripts/append-loop-event.py && ok "events have attempt_id" || bad "append-loop-event missing attempt_id"
[ -f "scripts/query-events.py" ] && ok "query-events.py present" || bad "missing query-events.py"

GATE_DIR="$TMP_ROOT/gate-proj"
mkdir -p "$GATE_DIR/.master/state" "$GATE_DIR/.master/docs" "$GATE_DIR/src"
# delegated + empty agents → block product write
printf '%s\n' '{"active":true,"execution_mode":"delegated","assigned_agents":[]}' > "$GATE_DIR/.master/state/loop.json"
set +e
printf '%s' '{"tool_input":{"file_path":"src/foo.ts"}}' | CLAUDE_PROJECT_DIR="$GATE_DIR" bash "$GATE_HOOK" >/dev/null 2>"$TMP_ROOT/gate-deny.err"
gate_rc=$?
[ "$gate_rc" = "2" ] && ok "delegated empty agents blocks product write" || bad "delegated empty agents should exit 2 (got $gate_rc)"
grep -q 'assigned_agents' "$TMP_ROOT/gate-deny.err" && ok "deny message mentions assigned_agents" || bad "deny message weak"

# Phase E: verify edit_blocked event written by gate hook
python3 - "$GATE_DIR/.master/state/history/events.jsonl" <<'PY' >/dev/null 2>&1 && ok "edit_blocked event written" || bad "missing edit_blocked event"
import json,sys
from pathlib import Path
lines=[l for l in Path(sys.argv[1]).read_text().splitlines() if l.strip()]
events=[json.loads(l) for l in lines]
assert any(e.get('type')=='edit_blocked' for e in events),f'no edit_blocked in {events}'
PY

# same fixture with assigned_agents → allow
printf '%s\n' '{"active":true,"execution_mode":"delegated","assigned_agents":["implementer"]}' > "$GATE_DIR/.master/state/loop.json"
set +e
printf '%s' '{"tool_input":{"file_path":"src/foo.ts"}}' | CLAUDE_PROJECT_DIR="$GATE_DIR" bash "$GATE_HOOK" >/dev/null 2>&1
gate_rc=$?
[ "$gate_rc" = "0" ] && ok "delegated with agents allows product write" || bad "delegated with agents should exit 0 (got $gate_rc)"

# direct mode → allow
printf '%s\n' '{"active":true,"execution_mode":"direct","assigned_agents":[]}' > "$GATE_DIR/.master/state/loop.json"
set +e
printf '%s' '{"tool_input":{"file_path":"src/foo.ts"}}' | CLAUDE_PROJECT_DIR="$GATE_DIR" bash "$GATE_HOOK" >/dev/null 2>&1
gate_rc=$?
[ "$gate_rc" = "0" ] && ok "direct mode allows product write" || bad "direct mode should exit 0 (got $gate_rc)"

# prep allowlist: AGENT_TASK.md under delegated empty agents
printf '%s\n' '{"active":true,"execution_mode":"parallel","assigned_agents":[]}' > "$GATE_DIR/.master/state/loop.json"
set +e
printf '%s' '{"file_path":"AGENT_TASK.md"}' | CLAUDE_PROJECT_DIR="$GATE_DIR" bash "$GATE_HOOK" >/dev/null 2>&1
gate_rc=$?
[ "$gate_rc" = "0" ] && ok "prep AGENT_TASK.md allowed under gate" || bad "AGENT_TASK.md should be allowed (got $gate_rc)"

# inactive loop → allow
printf '%s\n' '{"active":false,"execution_mode":"delegated","assigned_agents":[]}' > "$GATE_DIR/.master/state/loop.json"
set +e
printf '%s' '{"file_path":"src/foo.ts"}' | CLAUDE_PROJECT_DIR="$GATE_DIR" bash "$GATE_HOOK" >/dev/null 2>&1
gate_rc=$?
[ "$gate_rc" = "0" ] && ok "inactive loop allows product write" || bad "inactive loop should exit 0 (got $gate_rc)"


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
# Phase D: runtime_check schema present in template
python3 - <<'PYPD' >/dev/null 2>&1 && ok "templates/project.json has runtime_check field" || bad "templates/project.json missing runtime_check field"
import json
from pathlib import Path
d = json.loads(Path("templates/project.json").read_text())
assert "runtime_check" in d
PYPD

# Phase D: null runtime_check preserves GREEN (validate uses .master/project.json; template null is baseline)
grep -q "runtime_check" scripts/validate.sh && ok "validate.sh contains runtime_check stage" || bad "validate.sh missing runtime_check stage"

# Phase D: validate.sh with explicit runtime_check="false" → RED
RUNTIME_DIR="$TMP_ROOT/runtime-proj"
mkdir -p "$RUNTIME_DIR/.master/state"
printf '%s\n' '{"schema_version":1,"name":"rt","maturity":"new","iteration_budget":2,"stack":{},"validate_cmd":"","runtime_check":"false","allow_no_stack":true,"docs":{"manifest":[],"load_for_loop":false}}' > "$RUNTIME_DIR/.master/project.json"
CLAUDE_PROJECT_DIR="$RUNTIME_DIR" bash "$SELF_ROOT/scripts/validate.sh" >"$TMP_ROOT/rt.log" 2>&1 || true
grep -q "GATE: RED" "$TMP_ROOT/rt.log" && ok "runtime_check failing command → RED" || bad "runtime_check failing command should → RED"

# Phase D: null runtime_check → GREEN path unchanged
RUNTIME_NULL_DIR="$TMP_ROOT/runtime-null-proj"
mkdir -p "$RUNTIME_NULL_DIR/.master/state"
printf '%s\n' '{"schema_version":1,"name":"rt2","maturity":"new","iteration_budget":2,"stack":{},"validate_cmd":"","runtime_check":null,"allow_no_stack":true,"docs":{"manifest":[],"load_for_loop":false}}' > "$RUNTIME_NULL_DIR/.master/project.json"
CLAUDE_PROJECT_DIR="$RUNTIME_NULL_DIR" bash "$SELF_ROOT/scripts/validate.sh" >"$TMP_ROOT/rtnull.log" 2>&1 || true
grep -q "GATE: GREEN" "$TMP_ROOT/rtnull.log" && ok "runtime_check null → GREEN unchanged" || bad "runtime_check null should → GREEN"

if [ "${MASTER_SELF_CHECK_SKIP_VALIDATE:-0}" = 1 ]; then
  ok "full validation skipped inside npm test"
else
  bash scripts/validate.sh >"$TMP_ROOT/validate.log" 2>&1 || true
  grep -q 'GATE: ' "$TMP_ROOT/validate.log" && ok "validation reports verdict" || bad "validation verdict"
fi

echo
[ "$FAIL" -eq 0 ] && echo "Self-check OK" || echo "Self-check failed"
exit "$FAIL"
