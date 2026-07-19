#!/usr/bin/env bash
# Re-feed a compact continuation while an adaptive loop is active.
set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_FILE="$ROOT/.master/state/loop.json"
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$HOOK_DIR/../../scripts/write-handoff.py" ]]; then
  HANDOFF_SCRIPT="$HOOK_DIR/../../scripts/write-handoff.py"
else
  HANDOFF_SCRIPT="$HOOK_DIR/../scripts/write-handoff.py"
fi
[[ -f "$STATE_FILE" ]] || exit 0
HOOK_INPUT=$(cat)

python3 - "$STATE_FILE" "$HOOK_INPUT" "$ROOT/.master/state/validation-pending" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path

state_path = Path(sys.argv[1])
try:
    state = json.loads(state_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    print(f"Loop stopped: invalid state ({exc})", file=sys.stderr)
    state_path.unlink(missing_ok=True)
    raise SystemExit(0)

if not state.get("active") or state.get("status") in {"cancelled", "paused", "completed", "max_iterations"}:
    raise SystemExit(0)

try:
    hook = json.loads(sys.argv[2] or "{}")
except json.JSONDecodeError:
    hook = {}
transcript = Path(hook.get("transcript_path") or "")
if not transcript.is_file():
    state.update({"active": False, "status": "error", "next_action": "report_missing_transcript",
                  "updated_at": datetime.now(timezone.utc).isoformat()})
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("Loop stopped: transcript missing or unreadable.", file=sys.stderr)
    raise SystemExit(0)
last_output = ""
try:
    transcript_lines = transcript.read_text(encoding="utf-8", errors="replace").splitlines()
except OSError:
    state.update({"active": False, "status": "error", "next_action": "report_missing_transcript",
                  "updated_at": datetime.now(timezone.utc).isoformat()})
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("Loop stopped: transcript became unreadable.", file=sys.stderr)
    raise SystemExit(0)
for line in transcript_lines:
    try:
        row = json.loads(line)
    except json.JSONDecodeError:
        continue
    message = row.get("message") or {}
    if message.get("role") != "assistant" and row.get("role") != "assistant":
        continue
    content = message.get("content", row.get("content", []))
    if isinstance(content, str):
        last_output = content
    elif isinstance(content, list):
        last_output = "\n".join(
            str(item.get("text", "")) for item in content
            if isinstance(item, dict) and item.get("type") == "text"
        )

validation_green = ((state.get("validation") or {}).get("status") == "green" and not Path(sys.argv[3]).exists())
promise = state.get("completion_promise")
if promise:
    completion_signalled = f"<promise>{promise}</promise>" in last_output
else:
    completion_signalled = "<loop-complete/>" in last_output

now = datetime.now(timezone.utc).isoformat()
if completion_signalled and validation_green:
    state.update({"active": False, "status": "completed", "next_action": "write_handoff", "updated_at": now})
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("Loop complete: completion signal verified with validation GREEN.", file=sys.stderr)
    raise SystemExit(0)

iteration = int(state.get("iteration", 1))
maximum = int(state.get("max_iterations", 2))
if iteration >= maximum:
    state.update({"active": False, "status": "max_iterations", "next_action": "report_incomplete", "updated_at": now})
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print(f"Loop stopped: max iterations reached ({maximum}).")
    raise SystemExit(0)

state["iteration"] = iteration + 1
state["updated_at"] = now
state["next_action"] = "continue_execution"
state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")

graph = state.get("task_graph") or []
pending = [str(t.get("title") or t.get("id")) for t in graph if isinstance(t, dict) and t.get("status") != "completed"]
skills = state.get("selected_skills") or []
reason = (
    f"Continue task: {state.get('prompt')}\n"
    f"Iteration: {state['iteration']}/{maximum}. Execution mode: {state.get('execution_mode')}.\n"
    f"Pending subtasks: {', '.join(pending[:5]) or 'classify/continue current slice'}.\n"
    f"Selected skills: {', '.join(map(str, skills[:3])) or 'none'}.\n"
    "Read CLAUDE.md and .master/project.json only as needed. Implement and test. "
    "Run the configured validation command. Mark completion only when validation is GREEN."
)
print(json.dumps({
    "decision": "block",
    "reason": reason,
    "systemMessage": f"Loop iteration {state['iteration']}/{maximum}"
}))
PY

if python3 - "$STATE_FILE" <<'PY2' | grep -q '^completed$'
import json, sys
from pathlib import Path
try:
    print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("status", ""))
except Exception:
    pass
PY2
then
  python3 "$HANDOFF_SCRIPT" "$ROOT" >/dev/null 2>&1 || true
fi
