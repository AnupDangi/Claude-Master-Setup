#!/usr/bin/env bash
# Stop hook: desktop notification when loop ends / needs attention.
# Opt out: MASTER_DESKTOP_NOTIFY=0. Never blocks the session.
set -euo pipefail

if [[ "${MASTER_DESKTOP_NOTIFY:-1}" == "0" ]]; then
  exit 0
fi

ROOT="${CLAUDE_PROJECT_DIR:-.}"
STATE="$ROOT/.master/state/loop.json"
PENDING="$ROOT/.master/state/validation-pending"

if [[ ! -f "$STATE" ]]; then
  exit 0
fi

# Drain stdin so the hook host is not blocked
cat >/dev/null 2>&1 || true

eval "$(python3 - "$STATE" "$PENDING" <<'PY'
import json, sys
from pathlib import Path

state_path = Path(sys.argv[1])
pending = Path(sys.argv[2]).is_file()
try:
    state = json.loads(state_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    print("SKIP=1")
    raise SystemExit(0)

status = str(state.get("status") or "idle")
active = bool(state.get("active"))
phase = str(state.get("phase") or "")
iteration = state.get("iteration") or 0
max_it = state.get("max_iterations") or 0
mode = str(state.get("execution_mode") or "")
prompt = str(state.get("prompt") or "").strip().replace("\n", " ")
if len(prompt) > 80:
    prompt = prompt[:77] + "..."
project = Path(state_path).resolve().parents[2].name

title = ""
body = ""

if status == "completed":
    title = f"Master · Done — {project}"
    body = f"Loop completed (GREEN). {prompt or phase}"
elif status == "paused":
    title = f"Master · Needs you — {project}"
    reason = state.get("pause_reason") or "paused"
    body = f"Pending review / pause: {reason}. {prompt or ''}".strip()
elif status == "max_iterations":
    title = f"Master · Stopped — {project}"
    body = f"Hit max iterations ({iteration}/{max_it}). Check /status."
elif status == "error":
    title = f"Master · Error — {project}"
    err = state.get("last_error") or "error"
    body = str(err)[:120]
elif pending and (active or status == "running"):
    title = f"Master · Validate pending — {project}"
    body = f"{phase or 'build'} · {mode} · iteration {iteration}/{max_it}"
elif active and status == "running":
    # Still mid-loop — skip spam on every Stop continuation
    print("SKIP=1")
    raise SystemExit(0)
elif not active and status in {"idle", "cancelled", "unclassified", ""}:
    print("SKIP=1")
    raise SystemExit(0)
else:
    # Terminal-ish statuses we may have missed
    if status in {"completed", "paused", "max_iterations", "error"}:
        title = f"Master · {status} — {project}"
        body = prompt or phase or status
    else:
        print("SKIP=1")
        raise SystemExit(0)

def sh_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")

print(f'SKIP=0')
print(f'TITLE="{sh_escape(title)}"')
print(f'BODY="{sh_escape(body)}"')
PY
)"

if [[ "${SKIP:-1}" == "1" ]]; then
  exit 0
fi

# macOS Notification Center
if [[ "$(uname -s)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"${BODY}\" with title \"${TITLE}\"" >/dev/null 2>&1 || true
fi

exit 0
