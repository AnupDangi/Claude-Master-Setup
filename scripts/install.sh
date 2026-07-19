#!/usr/bin/env bash
# Harness CONTRIBUTOR setup — for developing the harness source itself.
# This is NOT the consumer install path.
#
# Consumer install (recommended):
#   npx claude-master-setup            # from inside your project
#   npx claude-master-setup --local    # same, explicit
#
# This script only runs when you have cloned this repo to work on the harness
# code itself. It wires the source tree for local development (not a shared install).
#
# Safe to re-run.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
echo "▶ Claude Master Setup — contributor/source setup…"

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
for pat in ".env" ".env.*" "!.env.example" ".master/state/" "/tmp/harness_*"; do
  grep -qxF "$pat" .gitignore || echo "$pat" >> .gitignore
done
echo "  ✓ .gitignore updated (secrets and .master/state/ excluded)"

# 4. Seed empty loop state in .master/state/ (ADR-007: project footprint)
mkdir -p .master/state
[ -f .master/state/loop.json ] || echo '{ "iteration": 0, "phase": "idle", "task": null, "validate_attempts": 0, "max_validate_retries": 3, "task_graph": null, "task_complexity": null, "plan_source": null, "review_dispatch": null, "skills_index": null, "skills_assigned": [], "skills_skipped": [], "fanout": null, "iterations_this_run": 0, "max_iterations_per_run": 1, "build_effort_tier": null, "build_effort_score": null, "docs_profile": null }' > .master/state/loop.json
echo "  ✓ loop state initialized at .master/state/loop.json"

# 5. Tool checks (warn only)
command -v node >/dev/null 2>&1 && echo "  ✓ node $(node -v)" || echo "  ! node not found (needed for some MCP servers)"
command -v claude >/dev/null 2>&1 && echo "  ✓ claude CLI present" || echo "  ! claude CLI not found — install: https://claude.ai/install.sh"

echo
echo "Next steps (harness development):"
echo "  1. bash scripts/self-check.sh   # verify harness source files"
echo "  2. node --check bin/cli.js       # syntax-check the CLI"
echo "  3. npm test                      # self-check + syntax validation"
echo
echo "Consumer quick-start (run in another project):"
echo "  npx claude-master-setup          # framework + seed this project"
echo "  claude && /bootstrap && /loop    # start building"
