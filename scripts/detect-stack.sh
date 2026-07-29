#!/usr/bin/env bash
# Detects the project's stack and package manager. Used by stack detection / skill install helpers.
# Prints one token: node-pnpm | node-yarn | node-npm | python-poetry | python-uv | python-pip | rust | go | make | unknown
detect_stack() {
  if [ -f package.json ]; then
    if [ -f pnpm-lock.yaml ]; then echo "node-pnpm"; return; fi
    if [ -f yarn.lock ]; then echo "node-yarn"; return; fi
    echo "node-npm"; return
  fi
  if [ -f pyproject.toml ]; then
    if [ -f poetry.lock ]; then echo "python-poetry"; return; fi
    if [ -f uv.lock ]; then echo "python-uv"; return; fi
    echo "python-pip"; return
  fi
  if [ -f requirements.txt ]; then echo "python-pip"; return; fi
  if [ -f Cargo.toml ]; then echo "rust"; return; fi
  if [ -f go.mod ]; then echo "go"; return; fi
  if [ -f Makefile ] || [ -f makefile ]; then echo "make"; return; fi
  echo "unknown"
}
