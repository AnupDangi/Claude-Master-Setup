#!/usr/bin/env bash
# Initialize or steer the adaptive Ralph-style loop state.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="$ROOT/.master/state"
STATE_FILE="$STATE_DIR/loop.json"
PROMPT_PARTS=()
MAX_ITERATIONS=""
COMPLETION_PROMISE=""

usage() {
  cat <<'HELP'
Usage: setup-loop.sh PROMPT [--max-iterations N] [--completion-promise TEXT]

Modes:
  - No active loop: start fresh (iteration 1)
  - active loop: steer (append correction, keep iteration, do not reset)
  - paused loop: resume with optional new prompt

Defaults:
  --max-iterations from .master/project.json iteration_budget (fallback 2)
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

path = Path(sys.argv[1])
prompt = sys.argv[2]
max_arg = sys.argv[3]
promise_arg = sys.argv[4]
now = datetime.now(timezone.utc).isoformat()

def base_fields():
    return {
        "correction_log": [],
        "await_clarify_questions": [],
        "architecture_pending": False,
        "phase": "gate",
        "ship_completed": False,
        "last_progress_at": now,
        "last_error": None,
        "stall_count": 0,
        "blocked_on": None,
        "progress_fingerprint": None,
    }

existing = None
if path.is_file():
    try:
        existing = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        existing = None

if existing and existing.get("active") and existing.get("status") == "running":
    log = list(existing.get("correction_log") or [])
    log.append({"at": now, "prompt": prompt})
    existing["correction_log"] = log
    existing["prompt"] = prompt
    existing["stall_count"] = 0
    existing["last_error"] = None
    existing["blocked_on"] = None
    existing["phase"] = "gate"
    existing["ship_completed"] = False
    existing["validation"] = {
        "status": "pending",
        "command": None,
        "agent": None,
        "checks": [],
        "checked_at": None,
    }
    existing["next_action"] = "steer_and_execute"
    existing["updated_at"] = now
    if max_arg:
        existing["max_iterations"] = int(max_arg)
    if promise_arg:
        existing["completion_promise"] = promise_arg
    path.write_text(json.dumps(existing, indent=2) + "\n", encoding="utf-8")
    print("STEER")
    raise SystemExit(0)

if existing and existing.get("status") == "paused":
    existing["active"] = True
    existing["status"] = "running"
    existing["prompt"] = prompt
    existing["pause_reason"] = None
    existing["stall_count"] = 0
    existing["validation"] = {
        "status": "pending",
        "command": None,
        "agent": None,
        "checks": [],
        "checked_at": None,
    }
    existing["phase"] = "plan" if existing.get("architecture_pending") else "gate"
    existing["next_action"] = "resume_execution"
    existing["updated_at"] = now
    if max_arg:
        existing["max_iterations"] = int(max_arg)
    if promise_arg:
        existing["completion_promise"] = promise_arg
    log = list(existing.get("correction_log") or [])
    log.append({"at": now, "prompt": prompt, "kind": "resume"})
    existing["correction_log"] = log
    path.write_text(json.dumps(existing, indent=2) + "\n", encoding="utf-8")
    print("RESUME")
    raise SystemExit(0)

# Prefer explicit --max-iterations; else project.json iteration_budget; else 2
max_iterations = None
if max_arg:
    max_iterations = int(max_arg)
else:
    proj = path.parent.parent / "project.json"  # .master/state → .master/project.json
    try:
        budget = json.loads(proj.read_text(encoding="utf-8")).get("iteration_budget")
        if isinstance(budget, int) and budget >= 1:
            max_iterations = budget
    except (OSError, json.JSONDecodeError, TypeError):
        pass
if max_iterations is None:
    max_iterations = 2
state = {
    "schema_version": 1,
    "active": True,
    "status": "running",
    "prompt": prompt,
    "iteration": 1,
    "max_iterations": max_iterations,
    "completion_promise": promise_arg or None,
    "complexity": "unclassified",
    "execution_mode": "unclassified",
    "task_graph": [],
    "selected_skills": [],
    "assigned_agents": [],
    "validation": {
        "status": "pending",
        "command": None,
        "agent": None,
        "checks": [],
        "checked_at": None,
    },
    "next_action": "classify_and_execute",
    "pause_reason": None,
    "started_at": now,
    "updated_at": now,
    **base_fields(),
}
path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
print("START")
PY

MODE=$(python3 - "$STATE_FILE" <<'PY' || true
import json, sys
from pathlib import Path
try:
    s = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    na = s.get("next_action")
    if na == "steer_and_execute":
        print("steer")
    elif na == "resume_execution":
        print("resume")
    else:
        print("start")
except Exception:
    print("start")
PY
)

if [[ "$MODE" = "steer" || "$MODE" = "resume" ]]; then
  : > "$ROOT/.master/state/validation-pending"
fi


if [[ "$MODE" != "steer" ]]; then
  ROUTE=$(python3 "$SCRIPT_DIR/classify-task.py" "$PROMPT")
  # ensure-skills: may install allowlisted missing skills, then select top-3
  SKILLS=$(CLAUDE_PROJECT_DIR="$ROOT" bash "$SCRIPT_DIR/ensure-skills.sh" "$PROMPT" 3 2>/dev/null || \
    CLAUDE_PROJECT_DIR="$ROOT" bash "$SCRIPT_DIR/select-skills.sh" "$PROMPT" 3 2>/dev/null || echo '[]')
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
if state.get("execution_mode") in (None, "unclassified"):
    state.update(route)
state["selected_skills"] = [
    {"name": s.get("name"), "path": s.get("path"), "source": s.get("source")}
    for s in skills[:3] if isinstance(s, dict)
]
p.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
PY
fi

ITER=$(python3 - "$STATE_FILE" <<'PY'
import json, sys
from pathlib import Path
s = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(f"{s.get('iteration', 1)}/{s.get('max_iterations', 2)}")
PY
)

case "$MODE" in
  steer) printf 'Loop steer: iteration %s (correction applied)\n' "$ITER" ;;
  resume) printf 'Loop resumed: iteration %s\n' "$ITER" ;;
  *) printf 'Loop started: iteration %s\n' "$ITER" ;;
esac
printf 'State: %s\n' "$STATE_FILE"
printf 'Task: %s\n' "$PROMPT"
if [[ -n "$COMPLETION_PROMISE" ]]; then
  printf 'Complete only when true: <promise>%s</promise> and validation GREEN\n' "$COMPLETION_PROMISE"
else
  printf 'Complete only with <loop-complete/> after SHIP phase and validation GREEN\n'
fi
