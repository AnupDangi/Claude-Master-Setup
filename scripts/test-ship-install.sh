#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
CFG="$(mktemp -d)"
trap 'rm -rf "$TMP" "$CFG"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

mkdir -p "$TMP/sample-checkout/src" "$TMP/sample-checkout/tests"
cd "$TMP/sample-checkout"
git init -q
cat > package.json <<'JSON'
{"name":"sample-checkout","scripts":{"test":"node --test","build":"node -c src/index.js"}}
JSON
cat > README.md <<'MD'
# Sample Checkout

Calculates checkout totals for a small storefront.
MD
echo 'module.exports = {}' > src/index.js
echo '' > tests/index.test.js

# Simulate an upgrade from the old, larger install surface.
mkdir -p "$CFG/commands" "$CFG/agents" "$CFG/skills/capability-orchestrator"
echo '${CLAUDE_PLUGIN_ROOT} legacy master command' > "$CFG/commands/plan.md"
echo 'my custom review command' > "$CFG/commands/review.md"
echo 'Claude Master Setup legacy agent' > "$CFG/agents/docs-writer.md"
echo 'name: capability-orchestrator' > "$CFG/skills/capability-orchestrator/SKILL.md"
echo '# stale placeholder' > "$CFG/statusline.sh"
printf '%s\n' '{"statusLine":{"type":"command","command":"python3 statusline.sh"}}' > "$CFG/settings.json"

# Skip network skill install in smoke test (installer still exercises the call path with skip)
MASTER_SKIP_SKILLS=1 node "$ROOT/bin/cli.js" --force --config-dir "$CFG" >/dev/null
test -f "$CFG/claude-master-setup/scripts/install-default-skills.sh" || fail 'install-default-skills.sh not shipped'
test -f "$CFG/claude-master-setup/templates/skills-allowlist.json" || fail 'skills-allowlist.json not shipped'
test -f "$CFG/claude-master-setup/scripts/install-skill.sh" || fail 'install-skill.sh not shipped'
test -f "$CFG/claude-master-setup/scripts/ensure-skills.sh" || fail 'ensure-skills.sh not shipped'

test -f CLAUDE.md || fail 'CLAUDE.md missing'
test -f .master/project.json || fail 'project.json missing'
test -f .master/state/loop.json || fail 'loop.json missing'
test -d .master/docs || fail '.master/docs missing'
# Docs are generate-on-demand: installer must NOT copy ROADMAP/DESIGN stubs
test ! -f .master/docs/ROADMAP.md || fail 'installer must not copy ROADMAP.md (bootstrap generates)'
test -f "$CFG/claude-master-setup/scripts/append-loop-event.py" || fail 'append-loop-event.py not shipped'
grep -q 'sample-checkout' CLAUDE.md || fail 'project name not inferred'
grep -q 'Calculates checkout totals' CLAUDE.md || fail 'mission not inferred'
! grep -qi 'AI OS\|subagent table\|harness architecture' CLAUDE.md || fail 'harness prose leaked'
python3 - <<'PY' || fail 'project metadata'
import json
p=json.load(open('.master/project.json'))
assert p['name']=='sample-checkout'
assert p['maturity'] in {'existing','production'}
assert p['stack']['detected'].startswith('Node.js')
PY

test ! -e .env || fail '.env created'
test ! -e .github || fail '.github created'
test ! -e .claude || fail '.claude copied into project'

PACK="$CFG/claude-master-setup"
for f in scripts/setup-loop.sh scripts/cancel-loop.sh scripts/classify-task.py scripts/write-handoff.py hooks/loop-stop-hook.sh; do
  test -f "$PACK/$f" || fail "shared runtime missing $f"
done
for f in COMPANIONS.md scripts/budget-check.sh scripts/loop-event.sh scripts/lease.sh scripts/mcp-catalog.json commands/plan.md agents/docs-writer.md agents/security.md; do
  test ! -e "$PACK/$f" || fail "dead runtime shipped: $f"
done

test -f "$ROOT/.claude/statusline.sh" || fail 'package source missing .claude/statusline.sh'
test -x "$CFG/statusline.sh" || fail 'statusline.sh not installed to config dir'
grep -q 'CLAUDE_PROJECT_DIR' "$CFG/statusline.sh" || fail 'installed statusline missing project-root logic'
! grep -q 'stale placeholder' "$CFG/statusline.sh" || fail 'stale statusline was not replaced'

python3 - "$CFG/settings.json" "$CFG" <<'PY' || fail 'statusLine not wired'
import json, sys
from pathlib import Path
s = json.load(open(sys.argv[1]))
cmd = (s.get("statusLine") or {}).get("command") or ""
assert "statusline.sh" in cmd and "python3" in cmd
assert "CLAUDE_PROJECT_DIR" not in cmd
assert Path(sys.argv[2], "statusline.sh").is_file()
assert ("HARNESS_" + "MAX_ITERATIONS_PER_RUN") not in s.get("env", {})
PY

printf '%s' '{"model":{"display_name":"Test"},"workspace":{"current_dir":"'"$TMP"'/sample-checkout"},"context_window":{"used_percentage":12}}' \
  | CLAUDE_PROJECT_DIR="$TMP/sample-checkout" python3 "$CFG/statusline.sh" \
  | grep -q '📁 sample-checkout' \
  || fail 'statusline did not render project name'

test ! -e "$CFG/commands/plan.md" || fail 'old command survived upgrade'
grep -q 'my custom review command' "$CFG/commands/review.md" || fail 'user command was overwritten'
test ! -e "$CFG/agents/docs-writer.md" || fail 'old agent survived upgrade'
test ! -e "$CFG/skills/capability-orchestrator" || fail 'old skill survived upgrade'

export CLAUDE_PROJECT_DIR="$TMP/sample-checkout" HOME="$TMP/home"
mkdir -p "$HOME"
bash "$PACK/scripts/setup-loop.sh" 'fix tax rounding' >/dev/null
test -f "$PACK/hooks/notify-stop.sh" || fail 'notify-stop.sh not shipped to framework'
test -f "$PACK/scripts/query-events.py" || fail 'query-events.py not shipped'
python3 - "$CFG/settings.json" <<'PY' || fail 'notify-stop not wired in settings'
import json, sys
s = json.load(open(sys.argv[1]))
ids = [e.get("id") for e in (s.get("hooks") or {}).get("Stop") or [] if e.get("id")]
assert "harness:notify-stop" in ids, ids
assert ids.count("harness:notify-stop") == 1, ids
PY
python3 - <<'PY' || fail 'event missing attempt_id'
import json
from pathlib import Path
lines = Path('.master/state/history/events.jsonl').read_text().strip().splitlines()
assert lines, 'no events'
row = json.loads(lines[-1])
assert row.get('attempt_id'), row
assert row.get('type') in {'loop_start', 'steer', 'resume'}, row
PY
printf '%s' '{"model":{"display_name":"Test"},"workspace":{"current_dir":"'"$TMP"'/sample-checkout"},"context_window":{"used_percentage":12}}' \
  | CLAUDE_PROJECT_DIR="$TMP/sample-checkout" python3 "$CFG/statusline.sh" \
  | grep -q '🔄' \
  || fail 'statusline missing loop segment'
python3 - <<'PY' || fail 'installed loop defaults'
import json
from pathlib import Path
s=json.load(open('.master/state/loop.json'))
proj=json.loads(Path('.master/project.json').read_text())
budget=proj.get('iteration_budget')
expected=budget if isinstance(budget,int) and budget>=1 else 2
assert s['max_iterations']==expected and s['execution_mode']=='direct', (s['max_iterations'], expected, s['execution_mode'])
PY
bash "$PACK/scripts/cancel-loop.sh" >/dev/null
python3 - <<'PY' || fail 'installed cancel'
import json
assert json.load(open('.master/state/loop.json'))['status']=='cancelled'
PY

# --- Idempotent re-install: exactly one harness:* id per phase ---
MASTER_SKIP_SKILLS=1 node "$ROOT/bin/cli.js" --force --config-dir "$CFG" >/dev/null
python3 - "$CFG/settings.json" <<'PY' || fail 'hook ids not unique after second install'
import json, sys
from collections import Counter
s = json.load(open(sys.argv[1]))
ids = []
for entries in (s.get("hooks") or {}).values():
    if not isinstance(entries, list):
        continue
    for e in entries:
        i = e.get("id") if isinstance(e, dict) else None
        if isinstance(i, str) and i.startswith("harness:"):
            ids.append(i)
c = Counter(ids)
expected = {
    "harness:session-start",
    "harness:pre-bash-guard",
    "harness:protect-paths",
    "harness:require-agents-before-edit",
    "harness:post-edit-track",
    "harness:loop-stop",
    "harness:stop-validate-reminder",
    "harness:notify-stop",
}
assert set(c) == expected, (set(c), expected)
assert all(n == 1 for n in c.values()), c
assert "HARNESS_FRAMEWORK_ROOT" not in json.dumps(s.get("env") or {})
# No leftover ID-less master hooks
for entries in (s.get("hooks") or {}).values():
    if not isinstance(entries, list):
        continue
    for e in entries:
        cmd = " ".join(h.get("command", "") for h in (e.get("hooks") or []))
        if "HARNESS_FRAMEWORK_ROOT" in cmd:
            raise SystemExit("legacy HARNESS_FRAMEWORK_ROOT hook survived")
PY

# --- --repair collapses duplicates + disables plugin ---
python3 - "$CFG/settings.json" <<'PY'
import json, sys
p = sys.argv[1]
s = json.load(open(p))
# Seed legacy duplicate hooks + plugin enabled
s.setdefault("hooks", {})
s["hooks"].setdefault("PreToolUse", [])
s["hooks"]["PreToolUse"].append({
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": 'bash "$HARNESS_FRAMEWORK_ROOT/hooks/pre-bash-guard.sh"'}],
})
s["hooks"]["PreToolUse"].append({
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": 'bash "$CLAUDE_MASTER_ROOT/hooks/pre-bash-guard.sh"'}],
    "id": "harness:pre-bash-guard",
})
s.setdefault("env", {})["HARNESS_FRAMEWORK_ROOT"] = "/tmp/legacy"
s.setdefault("enabledPlugins", {})["master@claude-master-setup"] = True
open(p, "w").write(json.dumps(s, indent=2) + "\n")
PY
MASTER_SKIP_SKILLS=1 node "$ROOT/bin/cli.js" --force --repair --config-dir "$CFG" >/dev/null
python3 - "$CFG/settings.json" <<'PY' || fail 'repair did not collapse hooks / disable plugin'
import json, sys
from collections import Counter
s = json.load(open(sys.argv[1]))
ids = []
for entries in (s.get("hooks") or {}).values():
    if not isinstance(entries, list):
        continue
    for e in entries:
        i = e.get("id") if isinstance(e, dict) else None
        if isinstance(i, str) and i.startswith("harness:"):
            ids.append(i)
        cmd = " ".join(h.get("command", "") for h in (e.get("hooks") or []))
        assert "HARNESS_FRAMEWORK_ROOT" not in cmd, cmd
c = Counter(ids)
assert c["harness:pre-bash-guard"] == 1, c
assert all(n == 1 for n in c.values()), c
assert not (s.get("env") or {}).get("HARNESS_FRAMEWORK_ROOT")
assert (s.get("enabledPlugins") or {}).get("master@claude-master-setup") is False
assert (s.get("env") or {}).get("CLAUDE_MASTER_ROOT")
PY

MASTER_SKIP_SKILLS=1 node "$ROOT/bin/cli.js" --force --doctor --config-dir "$CFG" >/dev/null \
  || fail 'doctor should exit 0 after repair'

echo 'Clean install smoke test: OK'
