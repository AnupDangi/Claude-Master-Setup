#!/usr/bin/env python3
"""Write compact cross-session handoff and optional memory candidate state."""

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def git(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", *args], stderr=subprocess.DEVNULL, text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
state_dir = root / ".master" / "state"
loop_path = state_dir / "loop.json"
state_dir.mkdir(parents=True, exist_ok=True)

try:
    loop = json.loads(loop_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    loop = {}

head = git("-C", str(root), "rev-parse", "HEAD")
branch = git("-C", str(root), "branch", "--show-current")
status = git("-C", str(root), "status", "--short")
upstream = git("-C", str(root), "rev-parse", "--abbrev-ref", "@{u}")
ahead = git("-C", str(root), "rev-list", "--count", "@{u}..HEAD") if upstream else ""
pushed = bool(upstream and ahead == "0")

graph = loop.get("task_graph") or []
remaining = [
    item for item in graph
    if isinstance(item, dict) and item.get("status") != "completed"
]

# Include all new loop state fields
handoff = {
    "schema_version": 2,
    "task": loop.get("prompt"),
    "status": loop.get("status", "unknown"),
    "phase": loop.get("phase"),
    "complexity": loop.get("complexity"),
    "execution_mode": loop.get("execution_mode"),
    "iteration": loop.get("iteration"),
    "max_iterations": loop.get("max_iterations"),
    "validation": loop.get("validation"),
    "commit": head or None,
    "branch": branch or None,
    "working_tree_clean": not bool(status),
    "remaining_tasks": remaining,
    "assigned_agents": loop.get("assigned_agents") or [],
    "correction_log": loop.get("correction_log") or [],
    "stall_count": loop.get("stall_count", 0),
    "last_error": loop.get("last_error"),
    "blocked_on": loop.get("blocked_on") or (loop.get("pause_reason") if loop.get("status") == "paused" else None),
    "blockers": [loop.get("pause_reason")] if loop.get("pause_reason") else [],
    "next_prompt": remaining[0].get("title") if remaining else None,
    "updated_at": datetime.now(timezone.utc).isoformat(),
}
(state_dir / "handoff.json").write_text(
    json.dumps(handoff, indent=2) + "\n", encoding="utf-8"
)

# Write memory candidate for any terminal status (not just completed)
terminal_statuses = {"completed", "max_iterations", "paused", "cancelled"}
loop_status = loop.get("status", "")
if loop_status in terminal_statuses and (pushed or loop.get("complexity") == "complex"):
    candidate = {
        "ready": loop_status == "completed",
        "reason": "pushed" if pushed else "complex_solution",
        "title": f"{loop_status.capitalize()}: {loop.get('prompt') or 'loop task'}",
        "observation": {
            "task": loop.get("prompt"),
            "status": loop_status,
            "phase": loop.get("phase"),
            "validation": loop.get("validation"),
            "commit": head or None,
            "execution_mode": loop.get("execution_mode"),
            "assigned_agents": loop.get("assigned_agents") or [],
            "stall_count": loop.get("stall_count", 0),
        },
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    (state_dir / "memory-pending.json").write_text(
        json.dumps(candidate, indent=2) + "\n", encoding="utf-8"
    )

print(state_dir / "handoff.json")
