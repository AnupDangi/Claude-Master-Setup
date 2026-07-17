#!/usr/bin/env bash
# SessionStart hook: orient a new session. Never fails the session.
ROOT="${CLAUDE_PROJECT_DIR:-.}"
echo "── Claude Master Setup ──────────────────────────────"
if [ -f "$ROOT/.claude/state/loop.json" ]; then
  echo "Loop state: $(cat "$ROOT/.claude/state/loop.json")"
fi
if [ -f "$ROOT/docs/PROJECT_STATE.md" ]; then
  echo "Read first: CLAUDE.md, docs/PROJECT_STATE.md, docs/SESSION.md, docs/DECISIONS.md"
  echo "Next: run /status to see where the loop is, or /loop to continue building."
else
  echo "No project bootstrapped yet. Add PRD.md + PTR.md, then run /bootstrap."
fi
echo "─────────────────────────────────────────────────────"
exit 0
