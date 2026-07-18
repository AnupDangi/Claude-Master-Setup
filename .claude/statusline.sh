#!/usr/bin/env python3
"""Claude Code status line — model, git branch, project, context bar, cost."""

import json
import os
import subprocess
import sys


try:
    data = json.load(sys.stdin)
except Exception:
    data = {}


def lookup(paths, default=""):
    for path in paths:
        obj = data
        ok = True
        for key in path:
            if isinstance(obj, dict) and key in obj:
                obj = obj[key]
            else:
                ok = False
                break
        if ok and obj not in (None, ""):
            return obj
    return default


model = lookup(
    [
        ("model", "display_name"),
        ("model", "name"),
    ],
    "Claude",
)

cost = lookup(
    [
        ("cost", "total_cost_usd"),
        ("cost", "total_usd"),
        ("session", "cost"),
    ],
    0,
)

context = lookup(
    [
        ("context_window", "used_percentage"),
        ("context", "percentage"),
    ],
    0,
)

try:
    context = int(float(context))
except Exception:
    context = 0

cwd = lookup(
    [
        ("workspace", "current_dir"),
        ("cwd",),
    ],
    os.getcwd(),
)

try:
    branch = subprocess.check_output(
        ["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"],
        stderr=subprocess.DEVNULL,
        text=True,
    ).strip()
except Exception:
    branch = ""

project = os.path.basename(cwd.rstrip(os.sep)) or "project"

blocks = 10
filled = min(blocks, max(0, context // 10))
bar = "█" * filled + "░" * (blocks - filled)

parts = [f"🤖 {model}"]
if branch:
    parts.append(f"🌿 {branch}")
parts.append(f"📁 {project}")
parts.append(f"{bar} {context}%")
try:
    parts.append(f"💰 ${float(cost):.2f}")
except Exception:
    pass

print(" | ".join(parts))
