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
import json, sys, hashlib, subprocess
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
                  "last_error": "transcript missing or unreadable",
                  "updated_at": datetime.now(timezone.utc).isoformat()})
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("Loop stopped: transcript missing or unreadable.", file=sys.stderr)
    raise SystemExit(0)

last_output = ""
try:
    transcript_lines = transcript.read_text(encoding="utf-8", errors="replace").splitlines()
except OSError:
    state.update({"active": False, "status": "error", "next_action": "report_missing_transcript",
                  "last_error": "transcript became unreadable",
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

now = datetime.now(timezone.utc).isoformat()

# === ANTI-STALL: progress fingerprint check ===
try:
    git_status = subprocess.check_output(
        ["git", "-C", str(state_path.parent.parent.parent), "status", "--short"],
        stderr=subprocess.DEVNULL, text=True
    ).strip()
    fingerprint = hashlib.sha256(git_status.encode()).hexdigest()[:16]
except Exception:
    fingerprint = None

prev_fingerprint = state.get("progress_fingerprint")
stall_count = int(state.get("stall_count", 0))

if fingerprint and fingerprint == prev_fingerprint and stall_count > 0:
    stall_count += 1
    state["stall_count"] = stall_count
    state["last_error"] = f"No git changes since last iteration (stall_count={stall_count})"
    if stall_count >= 2:
        state.update({
            "active": False, "status": "paused",
            "pause_reason": f"agents_stalled: no progress after {stall_count} iterations",
            "next_action": "await_human",
            "updated_at": now,
        })
        state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        print(f"Loop paused: stall detected after {stall_count} iterations with no git changes.", file=sys.stderr)
        raise SystemExit(0)
elif fingerprint:
    state["progress_fingerprint"] = fingerprint
    if fingerprint != prev_fingerprint:
        state["stall_count"] = 0
else:
    state["stall_count"] = stall_count

# === COMPLETION GATE CHECKS ===
validation_green = ((state.get("validation") or {}).get("status") == "green" and not Path(sys.argv[3]).exists())
promise = state.get("completion_promise")
if promise:
    completion_signalled = f"<promise>{promise}</promise>" in last_output
else:
    completion_signalled = "<loop-complete/>" in last_output

if completion_signalled:
    # Gate 1: validation must be green
    if not validation_green:
        state["last_error"] = "Completion signalled but validation is not GREEN — refusing to complete"
        state["stall_count"] = stall_count + 1
        state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        # Fall through to re-feed
    else:
        # Gate 2: for non-direct modes, assigned_agents must not be empty
        execution_mode = state.get("execution_mode", "direct")
        assigned_agents = state.get("assigned_agents") or []
        if execution_mode not in ("direct", "unclassified") and len(assigned_agents) == 0:
            state.update({
                "active": False, "status": "paused",
                "pause_reason": "agents_never_spawned: execution_mode is not direct but no agents were assigned",
                "last_error": "completion rejected: delegated/parallel mode requires assigned_agents",
                "next_action": "await_human",
                "updated_at": now,
            })
            state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
            print("Loop paused: delegated/parallel execution but assigned_agents is empty.", file=sys.stderr)
            raise SystemExit(0)

        # Gate 3: ship_completed must be true
        if not state.get("ship_completed"):
            state["last_error"] = "Completion signalled but ship_completed is not set — SHIP phase was skipped"
            state["stall_count"] = stall_count + 1
            state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
            # Fall through to re-feed
        else:
            # Gate 4: for delegated/parallel, validation.agent must be "validator"
            validation_agent = (state.get("validation") or {}).get("agent")
            if execution_mode not in ("direct", "unclassified") and validation_agent != "validator":
                state["last_error"] = (
                    f"Completion rejected: validation.agent='{validation_agent}' "
                    "but must be 'validator' for delegated/parallel tasks"
                )
                state["stall_count"] = stall_count + 1
                state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
                # Fall through to re-feed
            else:
                # All gates passed — complete
                state.update({"active": False, "status": "completed",
                               "next_action": "write_handoff", "updated_at": now})
                state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
                print("Loop complete: completion signal verified with validation GREEN.", file=sys.stderr)
                raise SystemExit(0)

# Not yet complete — check iteration cap
iteration = int(state.get("iteration", 1))
maximum = int(state.get("max_iterations", 2))
if iteration >= maximum:
    state.update({"active": False, "status": "max_iterations",
                  "next_action": "report_incomplete", "updated_at": now})
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
phase = state.get("phase", "build")
last_error = state.get("last_error") or ""
stall_info = f" Stall count: {state.get('stall_count', 0)}." if state.get("stall_count", 0) > 0 else ""

reason = (
    f"Continue task: {state.get('prompt')}\n"
    f"Iteration: {state['iteration']}/{maximum}. Phase: {phase}. Execution mode: {state.get('execution_mode')}.\n"
    f"Pending subtasks: {', '.join(pending[:5]) or 'continue current phase'}.\n"
    f"Selected skills: {', '.join(map(str, skills[:3])) or 'none'}.\n"
)
if last_error:
    reason += f"Last error: {last_error}\n"
reason += (
    f"{stall_info}\n"
    "Work through the phased pipeline: GATE→PLAN→BUILD→VALIDATE→REVIEW→SHIP→COMPLETE. "
    "Run the configured validation command. Set ship_completed=true before COMPLETE. "
    "Mark completion only when validation is GREEN and all gates pass."
)
print(json.dumps({
    "decision": "block",
    "reason": reason,
    "systemMessage": f"Loop iteration {state['iteration']}/{maximum} — phase: {phase}"
}))
PY

LOOP_STATUS=$(python3 - "$STATE_FILE" <<'PY2' 2>/dev/null || echo ""
import json, sys
from pathlib import Path
try:
    print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("status", ""))
except Exception:
    pass
PY2
)

if [[ "$LOOP_STATUS" == "completed" || "$LOOP_STATUS" == "max_iterations" || \
      "$LOOP_STATUS" == "paused" || "$LOOP_STATUS" == "error" ]]; then
  python3 "$HANDOFF_SCRIPT" "$ROOT" >/dev/null 2>&1 || true
fi
