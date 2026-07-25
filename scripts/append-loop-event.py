#!/usr/bin/env python3
"""Append a structured JSONL event to .master/state/history/events.jsonl.

Usage: append-loop-event.py TYPE [--ts TS] [--iteration N] [--mode MODE]
       [--phase PHASE] [--agents A,B,...] [--detail TEXT] [--root ROOT]
       [--attempt-id ID] [--parent-event ID] [--worktree PATH]

Event types: loop_start, steer, resume, edit_blocked, loop_complete,
             paused, max_iterations, validation_green, validation_red, loop_error

Graph fields (backward-compatible; older lines omit them):
  attempt_id   — stable id for this attempt node
  parent_event — attempt_id of the prior event this continues from
  worktree     — worktree path when running in a fanout slice
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def _last_attempt_id(events_file: Path) -> Optional[str]:
    if not events_file.is_file():
        return None
    try:
        lines = events_file.read_text(encoding="utf-8").splitlines()
    except OSError:
        return None
    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        aid = row.get("attempt_id")
        if isinstance(aid, str) and aid:
            return aid
    return None


def _default_attempt_id(event_type: str, iteration: Optional[int], ts: str) -> str:
    it = iteration if iteration is not None else 0
    stamp = ts.replace(":", "").replace("-", "")[:15]
    return f"{stamp}-{event_type}-i{it}"


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
    parser.add_argument("--attempt-id", default=None, dest="attempt_id")
    parser.add_argument("--parent-event", default=None, dest="parent_event")
    parser.add_argument("--worktree", default=None)
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

    events_file = events_dir / "events.jsonl"
    parent = args.parent_event
    if parent is None and args.type in {"steer", "resume", "validation_green", "validation_red", "loop_complete", "paused", "max_iterations", "loop_error", "edit_blocked"}:
        parent = _last_attempt_id(events_file)

    attempt_id = args.attempt_id or _default_attempt_id(args.type, args.iteration, ts)
    worktree = args.worktree or os.environ.get("MASTER_WORKTREE") or None

    event = {
        "ts": ts,
        "type": args.type,
        "iteration": args.iteration,
        "mode": args.mode or None,
        "phase": args.phase or None,
        "agents": agents,
        "detail": args.detail or None,
        "attempt_id": attempt_id,
        "parent_event": parent,
        "worktree": worktree,
    }

    try:
        with events_file.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(event) + "\n")
    except OSError as exc:
        print(f"append-loop-event: write failed: {exc}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
