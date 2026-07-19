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
handoff = {
    "schema_version": 1,
    "task": loop.get("prompt"),
    "status": loop.get("status", "unknown"),
    "complexity": loop.get("complexity"),
    "execution_mode": loop.get("execution_mode"),
    "iteration": loop.get("iteration"),
    "validation": loop.get("validation"),
    "commit": head or None,
    "branch": branch or None,
    "working_tree_clean": not bool(status),
    "remaining_tasks": remaining,
    "blockers": [loop.get("pause_reason")] if loop.get("pause_reason") else [],
    "next_prompt": remaining[0].get("title") if remaining else None,
    "updated_at": datetime.now(timezone.utc).isoformat(),
}
(state_dir / "handoff.json").write_text(
    json.dumps(handoff, indent=2) + "\n", encoding="utf-8"
)

# An agent with claude-mem tools may consume this candidate. It is deliberately
# local and non-blocking; repository state remains the source of truth.
if loop.get("status") == "completed" and (pushed or loop.get("complexity") == "complex"):
    candidate = {
        "ready": True,
        "reason": "pushed" if pushed else "complex_solution",
        "title": f"Completed: {loop.get('prompt') or 'loop task'}",
        "observation": {
            "task": loop.get("prompt"),
            "validation": loop.get("validation"),
            "commit": head or None,
            "execution_mode": loop.get("execution_mode"),
        },
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    (state_dir / "memory-pending.json").write_text(
        json.dumps(candidate, indent=2) + "\n", encoding="utf-8"
    )

print(state_dir / "handoff.json")
