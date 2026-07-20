#!/usr/bin/env python3
"""Append a structured JSONL event to .master/state/history/events.jsonl.

Usage: append-loop-event.py TYPE [--ts TS] [--iteration N] [--mode MODE]
       [--phase PHASE] [--agents A,B,...] [--detail TEXT] [--root ROOT]

Event types: loop_start, steer, resume, edit_blocked, loop_complete,
             paused, max_iterations, validation_green, validation_red, loop_error
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Append JSONL loop event")
    parser.add_argument("type", help="Event type string")
    parser.add_argument("--ts", default=None, help="ISO timestamp (default: now)")
    parser.add_argument("--iteration", type=int, default=None)
    parser.add_argument("--mode", default=None)
    parser.add_argument("--phase", default=None)
    parser.add_argument("--agents", default=None, help="Comma-separated agent names")
    parser.add_argument("--detail", default=None)
    parser.add_argument("--root", default=None, help="Project root (default: CLAUDE_PROJECT_DIR or cwd)")
    args = parser.parse_args()

    root = Path(args.root or os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd()))
    events_dir = root / ".master" / "state" / "history"
    try:
        events_dir.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        print(f"append-loop-event: cannot create events dir: {exc}", file=sys.stderr)
        sys.exit(0)

    ts = args.ts or datetime.now(timezone.utc).isoformat()
    agents: list[str] = []
    if args.agents:
        agents = [a.strip() for a in args.agents.split(",") if a.strip()]

    event = {
        "ts": ts,
        "type": args.type,
        "iteration": args.iteration,
        "mode": args.mode or None,
        "phase": args.phase or None,
        "agents": agents,
        "detail": args.detail or None,
    }

    events_file = events_dir / "events.jsonl"
    try:
        with events_file.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(event) + "\n")
    except OSError as exc:
        print(f"append-loop-event: write failed: {exc}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
