#!/usr/bin/env bash
# PreToolUse(Write|Edit|MultiEdit): in active delegated/parallel loops with empty
# assigned_agents, allow only control-plane prep paths; block product edits (exit 2).
set -euo pipefail

INPUT="$(cat)"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE="$ROOT/.master/state/loop.json"

# Missing or unreadable state → no-op
[ -f "$STATE" ] || exit 0

# Parse loop gate fields
eval "$(python3 - "$STATE" <<'PY'
import json, sys
path = sys.argv[1]
try:
    s = json.load(open(path))
except (OSError, json.JSONDecodeError):
    print("ACTIVE=0")
    print("MODE=")
    print("AGENTS_EMPTY=1")
    raise SystemExit(0)
active = bool(s.get("active"))
mode = str(s.get("execution_mode") or "")
agents = s.get("assigned_agents")
empty = agents is None or (isinstance(agents, list) and len(agents) == 0)
print(f"ACTIVE={1 if active else 0}")
print(f"MODE={mode}")
print(f"AGENTS_EMPTY={1 if empty else 0}")
PY
)"

# Inactive, direct, unclassified, or agents already assigned → allow
[ "$ACTIVE" = "1" ] || exit 0
case "$MODE" in
  delegated|parallel) ;;
  *) exit 0 ;;
esac
[ "$AGENTS_EMPTY" = "1" ] || exit 0

# Gate is active: parse file_path from tool stdin
FP="$(printf '%s' "$INPUT" | python3 -c '
import json, re, sys
raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError:
    m = re.search(r"\"file_path\"\s*:\s*\"((?:\\.|[^\"\\])*)\"", raw)
    print((bytes(m.group(1), "utf-8").decode("unicode_escape") if m else ""))
    raise SystemExit(0)
fp = data.get("file_path") or data.get("path") or ""
ti = data.get("tool_input")
if not fp and isinstance(ti, dict):
    fp = ti.get("file_path") or ti.get("path") or ""
print(fp or "")
')"

[ -z "$FP" ] && exit 0

# Resolve allowlist against project root (absolute or relative paths)
ALLOWED="$(python3 - "$ROOT" "$FP" <<'PY'
import os, sys
root = os.path.realpath(sys.argv[1])
fp = sys.argv[2]
fp_norm = fp.replace("\\", "/")
abs_fp = os.path.realpath(fp if os.path.isabs(fp) else os.path.join(root, fp))
try:
    rel = os.path.relpath(abs_fp, root).replace("\\", "/")
except ValueError:
    rel = fp_norm.lstrip("./")

allow = {
    ".master/state/loop.json",
    "AGENT_TASK.md",
    ".master/docs/DESIGN.md",
    ".master/docs/DECISIONS.md",
}
if rel in allow or fp_norm.rstrip("/") in allow:
    print("1")
else:
    print("0")
PY
)"

if [ "$ALLOWED" = "1" ]; then
  exit 0
fi

echo "BLOCKED by harness require-agents-before-edit: $FP" >&2
echo "Active loop is execution_mode=$MODE with empty assigned_agents." >&2
echo "Spawn a Task (implementer/planner/orchestrator) and set assigned_agents in .master/state/loop.json first." >&2
echo "Allowed prep writes only: .master/state/loop.json, AGENT_TASK.md, .master/docs/DESIGN.md, .master/docs/DECISIONS.md." >&2

# Append edit_blocked event (best-effort)
_hook_dir="$(cd "$(dirname "$0")" && pwd)"
_append_script=""
if [[ -f "$_hook_dir/../../scripts/append-loop-event.py" ]]; then
  _append_script="$_hook_dir/../../scripts/append-loop-event.py"
elif [[ -f "$_hook_dir/../scripts/append-loop-event.py" ]]; then
  _append_script="$_hook_dir/../scripts/append-loop-event.py"
fi
if [[ -n "$_append_script" ]]; then
  python3 "$_append_script" "edit_blocked" \
    --mode "$MODE" \
    --detail "blocked_path=$FP" \
    --root "$ROOT" 2>/dev/null || true
fi

exit 2
