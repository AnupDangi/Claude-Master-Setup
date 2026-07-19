#!/usr/bin/env bash
# Initialize the adaptive Ralph-style loop state.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="$ROOT/.master/state"
STATE_FILE="$STATE_DIR/loop.json"
PROMPT_PARTS=()
MAX_ITERATIONS=2
COMPLETION_PROMISE=""

usage() {
  cat <<'HELP'
Usage: setup-loop.sh PROMPT [--max-iterations N] [--completion-promise TEXT]

Defaults:
  --max-iterations 2
  --completion-promise unset (finish with <loop-complete/> after validation GREEN)
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --max-iterations)
      [[ -n "${2:-}" && "$2" =~ ^[1-9][0-9]*$ ]] || {
        echo "Error: --max-iterations requires an integer greater than 0" >&2; exit 2;
      }
      MAX_ITERATIONS="$2"; shift 2 ;;
    --completion-promise)
      [[ -n "${2:-}" ]] || { echo "Error: --completion-promise requires text" >&2; exit 2; }
      COMPLETION_PROMISE="$2"; shift 2 ;;
    --*) echo "Error: unknown option $1" >&2; exit 2 ;;
    *) PROMPT_PARTS+=("$1"); shift ;;
  esac
done

PROMPT="${PROMPT_PARTS[*]}"
[[ -n "$PROMPT" ]] || { echo "LOOP_NOT_STARTED: prompt is required"; usage; exit 2; }
mkdir -p "$STATE_DIR"

python3 - "$STATE_FILE" "$PROMPT" "$MAX_ITERATIONS" "$COMPLETION_PROMISE" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path

path, prompt, max_iterations, promise = sys.argv[1:]
state = {
    "schema_version": 1,
    "active": True,
    "status": "running",
    "prompt": prompt,
    "iteration": 1,
    "max_iterations": int(max_iterations),
    "completion_promise": promise or None,
    "complexity": "unclassified",
    "execution_mode": "unclassified",
    "task_graph": [],
    "selected_skills": [],
    "assigned_agents": [],
    "validation": {"status": "pending", "command": None, "checked_at": None},
    "next_action": "classify_and_execute",
    "pause_reason": None,
    "started_at": datetime.now(timezone.utc).isoformat(),
    "updated_at": datetime.now(timezone.utc).isoformat(),
}
Path(path).write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
PY

# Add a cheap routing hint and a bounded local-skill shortlist. The loop model
# may refine routing after inspecting the repository.
ROUTE=$(python3 "$SCRIPT_DIR/classify-task.py" "$PROMPT")
SKILLS=$(CLAUDE_PROJECT_DIR="$ROOT" bash "$SCRIPT_DIR/select-skills.sh" "$PROMPT" 3 2>/dev/null || echo '[]')
python3 - "$STATE_FILE" "$ROUTE" "$SKILLS" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
state = json.loads(p.read_text(encoding="utf-8"))
route = json.loads(sys.argv[2])
try:
    skills = json.loads(sys.argv[3])
except json.JSONDecodeError:
    skills = []
state.update(route)
state["selected_skills"] = [
    {"name": s.get("name"), "path": s.get("path"), "source": s.get("source")}
    for s in skills[:3] if isinstance(s, dict)
]
p.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
PY

printf 'Loop started: iteration 1/%s\n' "$MAX_ITERATIONS"
printf 'State: %s\n' "$STATE_FILE"
printf 'Task: %s\n' "$PROMPT"
if [[ -n "$COMPLETION_PROMISE" ]]; then
  printf 'Complete only when true: <promise>%s</promise> and validation GREEN\n' "$COMPLETION_PROMISE"
else
  printf 'Complete only with <loop-complete/> and validation GREEN\n'
fi
