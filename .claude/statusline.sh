#!/usr/bin/env python3

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

model = lookup([
    ("model", "display_name"),
    ("model", "name")
], "Claude")

cost = lookup([
    ("cost", "total_cost_usd"),
    ("cost", "total_usd"),
    ("session", "cost")
], 0)

context = lookup([
    ("context_window", "used_percentage"),
    ("context", "percentage"),
    ("workspace", "current_dir", "context_percentage")
], 0)

try:
    context = int(float(context))
except:
    context = 0

five_hour = lookup([("rate_limits", "five_hour", "used_percentage")], None)
seven_day = lookup([("rate_limits", "seven_day", "used_percentage")], None)

def to_pct(value):
    try:
        return max(0, min(100, int(float(value))))
    except:
        return None

five_hour = to_pct(five_hour)
seven_day = to_pct(seven_day)

# Git branch
try:
    branch = subprocess.check_output(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        stderr=subprocess.DEVNULL,
        text=True
    ).strip()
except:
    branch = ""

project = os.path.basename(os.getcwd())

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
    # a nonzero pct should always show at least a sliver, even if rounding hit 0
    elif pct > 0 and full == 0:
        filled_str = PARTIALS[1]
        empty_count -= 1

    color = color_for(pct)
    return f"{color}{filled_str}{DIM}{'░' * empty_count}{RESET}"

parts = []

parts.append(f"🤖 {model}")

if branch:
    parts.append(f"🌿 {branch}")

parts.append(f"📁 {project}")

parts.append(f"session {make_bar(context)} {context}%")

if five_hour is not None:
    parts.append(f"⏳5h {make_bar(five_hour, blocks=5)} {five_hour}%")

if seven_day is not None:
    parts.append(f"🗓️7d {make_bar(seven_day, blocks=5)} {seven_day}%")

try:
    parts.append(f"💰 ${float(cost):.2f}")
except:
    pass

print(" | ".join(parts))
