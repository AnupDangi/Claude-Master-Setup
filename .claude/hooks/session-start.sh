#!/usr/bin/env bash
# SessionStart hook: orient a new session. Never fails the session.
ROOT="${CLAUDE_PROJECT_DIR:-.}"
echo "── Claude Master Setup ──────────────────────────────"
if [ -f "$ROOT/.master/state/loop.json" ]; then
  echo "Loop state: $(cat "$ROOT/.master/state/loop.json")"
fi
if [ -f "$ROOT/.master/docs/PROJECT_STATE.md" ]; then
  echo "Read first: CLAUDE.md, .master/docs/PROJECT_STATE.md, .master/docs/SESSION.md, .master/docs/DECISIONS.md"
  echo "Next: run /status to see where the loop is, or /loop to continue building."
else
  echo "No project bootstrapped yet. Add PRD.md + PTR.md, then run /bootstrap."
fi
echo "─────────────────────────────────────────────────────"
exit 0
