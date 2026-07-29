#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FAIL=0
ok() { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✗ %s\n' "$1"; FAIL=1; }

echo "Agent Master v1.1 self-check"

required_commands="bootstrap cancel checkpoint complete handoff init loop pause start status validate"
actual_commands="$(for f in .claude/commands/*.md; do basename "$f" .md; done | sort | tr '\n' ' ' | sed 's/ $//')"
[ "$actual_commands" = "$required_commands" ] \
  && ok "Claude command set" || bad "Claude command set: $actual_commands"

for file in bin/cli.js bin/compat-cli.js lib/agent-master.js; do
  node --check "$file" >/dev/null 2>&1 && ok "syntax $file" || bad "syntax $file"
done

for file in scripts/*.sh .claude/hooks/*.sh; do
  bash -n "$file" >/dev/null 2>&1 || bad "shell syntax $file"
done
ok "shell syntax"

python3 - <<'PY' >/dev/null 2>&1 && ok "schema, manifests, and package identity" || bad "schema, manifests, or package identity"
import json
from pathlib import Path

pkg = json.loads(Path("package.json").read_text())
plugin = json.loads(Path(".claude-plugin/plugin.json").read_text())
market = json.loads(Path(".claude-plugin/marketplace.json").read_text())
project = json.loads(Path("templates/project.json").read_text())

assert pkg["name"] == "agent-master-setup"
assert pkg["version"] == "1.1.0"
assert pkg["version"] == plugin["version"] == market["plugins"][0]["version"]
assert set(pkg["bin"]) == {"agent-master", "agent-master-setup", "claude-master-setup"}
assert project["schema_version"] == 2
assert isinstance(project["test_commands"], list)
assert "sources_of_truth" in project
# Dead loop.json orchestration scripts must not ship
for dead in [
    "scripts/setup-loop.sh", "scripts/cancel-loop.sh", "scripts/validate.sh",
    "scripts/worktree-fanout.sh", "scripts/classify-task.py", "scripts/write-handoff.py",
    "scripts/append-loop-event.py", "scripts/query-events.py",
]:
    assert dead not in pkg["files"], dead

for adapter in ["claude-code", "codex", "cursor"]:
    manifest = json.loads(Path(f"adapters/{adapter}/capabilities.json").read_text())
    assert manifest["adapter"] == adapter
    assert manifest["version"] == "1.1.0"
    assert manifest["capabilities"]["project_instructions"] is True
PY

python3 - <<'PY' >/dev/null 2>&1 && ok "Claude hooks are optional enhancements" || bad "Claude hooks still enforce legacy orchestration"
import json
from pathlib import Path
for file in [".claude/settings.json", ".claude-plugin/plugin.json"]:
    hooks = json.loads(Path(file).read_text()).get("hooks", {})
    ids = {
        entry.get("id")
        for entries in hooks.values()
        for entry in entries
        if isinstance(entry, dict)
    }
    assert "harness:require-agents-before-edit" not in ids
    assert "harness:loop-stop" not in ids
    assert "harness:post-edit-track" not in ids
    assert {"harness:session-start", "harness:pre-bash-guard", "harness:protect-paths", "harness:notify-stop"} <= ids
PY

# Security regressions
python3 - <<'PYSEC' >/dev/null 2>&1 && ok "notify-stop.sh has no eval" || bad "notify-stop.sh still uses eval"
import re
from pathlib import Path
lines = Path(".claude/hooks/notify-stop.sh").read_text().splitlines()
for line in lines:
    code = line.split("#", 1)[0]
    if re.search(r"(^|[^A-Za-z0-9_])eval\s", code):
        raise SystemExit("eval found")
PYSEC
grep -q 'RUN_ID_RE' .claude/hooks/notify-stop.sh \
  && ok "notify-stop.sh validates run_id" || bad "notify-stop.sh missing run_id guard"
grep -q 'relative_to' .claude/hooks/notify-stop.sh \
  && ok "notify-stop.sh rejects path escape" || bad "notify-stop.sh missing path escape guard"
grep -q 'RUN_ID_RE' .claude/hooks/session-start.sh \
  && ok "session-start.sh validates run_id" || bad "session-start.sh missing run_id guard"
grep -q 'relative_to' .claude/hooks/session-start.sh \
  && ok "session-start.sh rejects path escape" || bad "session-start.sh missing path escape guard"

# Commands must quote "$ARGUMENTS"
python3 - <<'PY' >/dev/null 2>&1 && ok 'commands quote "$ARGUMENTS"' || bad 'unquoted $ARGUMENTS in commands'
from pathlib import Path
import re
for path in Path(".claude/commands").glob("*.md"):
    text = path.read_text()
    if "$ARGUMENTS" not in text:
        continue
    # bare $ARGUMENTS (not preceded by ")
    if re.search(r'(?<!")\$ARGUMENTS', text):
        raise SystemExit(f"unquoted in {path}")
PY

for template in MASTER_README.md AGENTS.md.starter CLAUDE.md.starter CURSOR.mdc.starter project.json; do
  [ -f "templates/$template" ] && ok "template $template" || bad "missing template $template"
done

grep -q 'agent-master status --format json' templates/AGENTS.md.starter \
  && ok "AGENTS adapter resumes portable state" || bad "AGENTS adapter workflow"
grep -q 'Native agent memory' templates/MASTER_README.md \
  && ok "protocol separates native memory" || bad "native memory boundary"
grep -q 'node.*bin/cli.js' .claude/commands/start.md \
  && ok "Claude commands call universal CLI" || bad "Claude start is not CLI-backed"
grep -qi 'compatibility' .claude/commands/loop.md \
  && ok "legacy loop alias retained" || bad "legacy loop alias missing"

# Dead scripts must be gone
for runtime in setup-loop.sh cancel-loop.sh validate.sh worktree-fanout.sh classify-task.py write-handoff.py append-loop-event.py query-events.py; do
  [ ! -e "scripts/$runtime" ] && ok "legacy removed $runtime" || bad "legacy still present $runtime"
done

# Live skill scripts remain
for runtime in detect-stack.sh list-local-skills.sh select-skills.sh install-skill.sh ensure-skills.sh install-default-skills.sh; do
  [ -f "scripts/$runtime" ] && ok "skill runtime $runtime" || bad "missing skill runtime $runtime"
done

node bin/cli.js help 2>&1 | grep -q 'agent-master checkpoint' \
  && ok "universal help" || bad "universal help missing commands"
node bin/cli.js --repair --help 2>&1 | grep -q -- '--repair' \
  && ok "legacy installer help" || bad "legacy installer help"

for required in README.md docs/SETUP.md docs/LOOP.md docs/SECURITY.md docs/CHANGELOG.md; do
  [ -f "$required" ] && ok "$required" || bad "missing $required"
done

if [ "$FAIL" -ne 0 ]; then
  echo
  echo "Self-check failed" >&2
  exit 1
fi

echo
echo "Self-check passed"
