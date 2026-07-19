#!/usr/bin/env bash
# One-shot setup for the harness. Safe to re-run.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
echo "▶ Installing Claude Master Setup harness…"

# 1. Make scripts and hooks executable
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x .claude/hooks/*.sh 2>/dev/null || true
echo "  ✓ scripts and hooks are executable"

# 2. Seed .env.example -> .env (never overwrite an existing .env)
if [ -f .env.example ] && [ ! -f .env ]; then
  cp .env.example .env
  echo "  ✓ created .env from .env.example (fill in your secrets)"
fi

# 3. Ensure .env and local state are gitignored
touch .gitignore
for pat in ".env" ".env.*" "!.env.example" ".claude/state/" "/tmp/harness_*"; do
  grep -qxF "$pat" .gitignore || echo "$pat" >> .gitignore
done
echo "  ✓ .gitignore updated (secrets and local state excluded)"

# 4. Seed empty loop state
mkdir -p .claude/state
[ -f .claude/state/loop.json ] || echo '{ "iteration": 0, "phase": "idle", "task": null, "validate_attempts": 0, "max_validate_retries": 3, "task_graph": null, "task_complexity": null, "plan_source": null, "review_dispatch": null, "skills_index": null, "skills_assigned": [], "skills_skipped": [], "fanout": null, "iterations_this_run": 0, "max_iterations_per_run": 1, "build_effort_tier": null, "build_effort_score": null, "docs_profile": null }' > .claude/state/loop.json
echo "  ✓ loop state initialized"

# 5. Tool checks (warn only)
command -v node >/dev/null 2>&1 && echo "  ✓ node $(node -v)" || echo "  ! node not found (needed for some MCP servers)"
command -v claude >/dev/null 2>&1 && echo "  ✓ claude CLI present" || echo "  ! claude CLI not found — install: https://claude.ai/install.sh"

echo
echo "Next steps:"
echo "  1. Add PRD.md and PTR.md to the repo root."
echo "  2. Start Claude Code:  claude"
echo "  3. Run:  /bootstrap   then   /loop"
echo "  4. Verify the harness:  bash scripts/self-check.sh"
