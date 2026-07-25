#!/usr/bin/env python3
"""Print recent loop events with attempt lineage (JSONL reader).

Usage: query-events.py [--root ROOT] [--last N] [--json]
"""
import argparse
import json
import os
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Query .master/state/history/events.jsonl")
    parser.add_argument("--root", default=None)
    parser.add_argument("--last", type=int, default=10)
    parser.add_argument("--json", action="store_true", help="Emit JSON array")
    args = parser.parse_args()

    root = Path(args.root or os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd()))
    events_file = root / ".master" / "state" / "history" / "events.jsonl"
    if not events_file.is_file():
        if args.json:
            print("[]")
        else:
            print("no events yet")
        return

    rows: list[dict] = []
    try:
        for line in events_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    except OSError as exc:
        print(f"query-events: {exc}", file=sys.stderr)
        sys.exit(1)

    rows = rows[-max(1, args.last) :]
    if args.json:
        print(json.dumps(rows, indent=2))
        return

    if not rows:
        print("no events yet")
        return

    for row in rows:
        ts = str(row.get("ts") or "")[:19]
        et = row.get("type") or "?"
        aid = row.get("attempt_id") or "-"
        parent = row.get("parent_event") or ""
        wt = row.get("worktree") or ""
        lineage = f" ← {parent}" if parent else ""
        extra = f" wt={wt}" if wt else ""
        print(f"{ts}  {et}  [{aid}]{lineage}{extra}")


if __name__ == "__main__":
    main()
