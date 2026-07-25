#!/usr/bin/env python3
"""Claude Code status line — model, git, project, session/5h/7d bars, cost.

Canonical install: ~/.claude/statusline.sh (user-level only).
Wire via ~/.claude/settings.json:
  python3 "$HOME/.claude/statusline.sh"

Project folders must NOT set statusLine to $CLAUDE_PROJECT_DIR/.claude/… —
that path is for hooks/scripts, not the status bar.

Project name + git always resolve from the Claude project root
($CLAUDE_PROJECT_DIR), never from a nested cwd.
"""

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


def git_toplevel(start):
    if not start or not os.path.isdir(start):
        return ""
    try:
        return subprocess.check_output(
            ["git", "-C", start, "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        return ""


def project_root():
    """Prefer Claude project root env; never basename of a nested workspace path."""
    env_root = (os.environ.get("CLAUDE_PROJECT_DIR") or "").strip()
    if env_root and os.path.isdir(env_root):
        return os.path.abspath(env_root)

    workspace = lookup(
        [
            ("workspace", "project_dir"),
            ("workspace", "current_dir"),
            ("cwd",),
        ],
        "",
    )
    if workspace:
        top = git_toplevel(workspace)
        if top:
            return top
        if os.path.isdir(workspace):
            return os.path.abspath(workspace)

    top = git_toplevel(os.getcwd())
    if top:
        return top
    return os.path.abspath(os.getcwd())


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


def to_pct(value):
    try:
        return max(0, min(100, int(float(value))))
    except Exception:
        return None


five_hour = to_pct(lookup([("rate_limits", "five_hour", "used_percentage")], None))
seven_day = to_pct(lookup([("rate_limits", "seven_day", "used_percentage")], None))

root = project_root()
project = os.path.basename(root.rstrip(os.sep)) or "project"

try:
    branch = subprocess.check_output(
        ["git", "-C", root, "rev-parse", "--abbrev-ref", "HEAD"],
        stderr=subprocess.DEVNULL,
        text=True,
    ).strip()
except Exception:
    branch = ""

RESET = "\033[0m"
DIM = "\033[90m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"


def color_for(pct):
    if pct >= 80:
        return RED
    if pct >= 50:
        return YELLOW
    return GREEN


PARTIALS = " ▏▎▍▌▋▊▉"  # index 0..7 eighths of a block


def make_bar(pct, blocks=10):
    pct = max(0, min(100, pct))
    total_eighths = blocks * 8
    filled_eighths = round(pct / 100.0 * total_eighths)
    full = filled_eighths // 8
    partial_idx = filled_eighths % 8

    filled_str = "█" * full
    empty_count = blocks - full
    if partial_idx > 0 and empty_count > 0:
        filled_str += PARTIALS[partial_idx]
        empty_count -= 1
    elif pct > 0 and full == 0:
        filled_str = PARTIALS[1]
        empty_count -= 1

    color = color_for(pct)
    return f"{color}{filled_str}{DIM}{'░' * empty_count}{RESET}"


parts = [f"🤖 {model}"]
if branch:
    parts.append(f"🌿 {branch}")
parts.append(f"📁 {project}")

# Loop awareness from .master/state/loop.json (Master harness)
loop_seg = ""
try:
    loop_path = os.path.join(root, ".master", "state", "loop.json")
    if os.path.isfile(loop_path):
        with open(loop_path, encoding="utf-8") as fh:
            loop = json.load(fh)
        st = str(loop.get("status") or "idle")
        active = bool(loop.get("active"))
        phase = str(loop.get("phase") or "")
        mode = str(loop.get("execution_mode") or "")
        it = loop.get("iteration")
        mx = loop.get("max_iterations")
        show = active or st in {
            "running",
            "paused",
            "completed",
            "max_iterations",
            "error",
            "cancelled",
        }
        if show and st not in {"idle", ""}:
            bits = []
            if phase:
                bits.append(phase)
            if it is not None and mx is not None:
                bits.append(f"{it}/{mx}")
            elif it is not None:
                bits.append(str(it))
            if mode and mode != "unclassified":
                bits.append(mode)
            bits.append(st)
            loop_seg = "🔄 " + " · ".join(bits)
except Exception:
    loop_seg = ""
if loop_seg:
    parts.append(loop_seg)

parts.append(f"session {make_bar(context)} {context}%")
if five_hour is not None:
    parts.append(f"⏳5h {make_bar(five_hour, blocks=5)} {five_hour}%")
if seven_day is not None:
    parts.append(f"🗓️7d {make_bar(seven_day, blocks=5)} {seven_day}%")
try:
    parts.append(f"💰 ${float(cost):.2f}")
except Exception:
    pass

print(" | ".join(parts))
