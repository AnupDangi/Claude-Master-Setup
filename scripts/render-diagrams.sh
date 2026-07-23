#!/usr/bin/env bash
# Render docs/*.mmd → docs/*.png for GitHub + npm README (npm does not run Mermaid).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MMDC=(npx -y @mermaid-js/mermaid-cli@11.12.0)
# Prefer local mmdc if present (after npm i -D)
if command -v mmdc >/dev/null 2>&1; then
  MMDC=(mmdc)
elif [ -x "$ROOT/node_modules/.bin/mmdc" ]; then
  MMDC=("$ROOT/node_modules/.bin/mmdc")
fi

render() {
  local in="$1" out="$2"
  echo "→ ${in} → ${out}"
  "${MMDC[@]}" -i "$in" -o "$out" -b transparent -w 1800
}

render docs/architecture.mmd docs/architecture.png
render docs/control-plane.mmd docs/control-plane.png
render docs/loop-phases.mmd docs/loop-phases.png

echo "Done. PNGs ready for README absolute GitHub URLs."
