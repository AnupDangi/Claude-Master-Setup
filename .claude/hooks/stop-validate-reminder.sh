#!/usr/bin/env bash
# Stop hook: if source changed this session but the gate wasn't run, remind.
# Never blocks — just prints.
ROOT="${CLAUDE_PROJECT_DIR:-.}"
if [ -f "$ROOT/.claude/state/validation-pending" ]; then
  echo "REMINDER: source changed but the validation gate hasn't confirmed GREEN this cycle."
  echo "Run /validate (or bash scripts/validate.sh) before committing — the loop hard-blocks on RED."
fi
exit 0
