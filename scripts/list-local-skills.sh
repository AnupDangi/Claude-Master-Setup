#!/usr/bin/env bash
# Enumerate local Claude Code skills (filesystem only — no web/marketplace).
# Prints a JSON array of { name, description, path, source }.
# Priority on duplicate names: project > user > plugin.
#
# Env:
#   HARNESS_SKILLS_SOURCES   comma list: project,user,plugin (default: all three)
#   HARNESS_SKILLS_MAX       max skills to emit (default 80)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export REPO_ROOT
export HOME
export HARNESS_SKILLS_SOURCES="${HARNESS_SKILLS_SOURCES:-project,user,plugin}"
export HARNESS_SKILLS_MAX="${HARNESS_SKILLS_MAX:-80}"

python3 <<'PY'
import json
import os
import re
from pathlib import Path

repo = Path(os.environ["REPO_ROOT"])
home = Path(os.environ["HOME"])
sources = {s.strip() for s in os.environ.get("HARNESS_SKILLS_SOURCES", "project,user,plugin").split(",") if s.strip()}
try:
    max_skills = max(1, int(os.environ.get("HARNESS_SKILLS_MAX", "80")))
except ValueError:
    max_skills = 80

def frontmatter(text: str) -> dict:
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    meta = {}
    lines = parts[1].splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line.strip())
        if not m:
            i += 1
            continue
        key, val = m.group(1), m.group(2).strip()
        # Folded/literal block scalars: description: >  or |
        if val in (">", ">-", "|", "|-") or val.startswith(">") or val.startswith("|"):
            block = []
            i += 1
            while i < len(lines):
                nxt = lines[i]
                if re.match(r"^[A-Za-z0-9_-]+:\s*", nxt) and not nxt.startswith(" "):
                    break
                if nxt.startswith("  ") or nxt.startswith("\t") or nxt.strip() == "":
                    block.append(nxt.strip())
                    i += 1
                    continue
                break
            val = " ".join(x for x in block if x)
            meta[key] = val[:1024]
            continue
        if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
            val = val[1:-1]
        meta[key] = val
        i += 1
    return meta

def collect(base: Path, source: str, by_name: dict):
    if not base.is_dir():
        return
    for skill_md in sorted(base.glob("*/SKILL.md")):
        if len(by_name) >= max_skills:
            return
        try:
            text = skill_md.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        meta = frontmatter(text)
        name = meta.get("name") or skill_md.parent.name
        if not re.match(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$", name):
            continue
        if name in by_name:
            continue
        desc = meta.get("description", "")[:1024]
        by_name[name] = {
            "name": name,
            "description": desc,
            "path": str(skill_md.resolve()),
            "source": source,
        }

by_name = {}
if "project" in sources:
    collect(repo / ".claude" / "skills", "project", by_name)
if "user" in sources:
    collect(home / ".claude" / "skills", "user", by_name)

if "plugin" in sources and len(by_name) < max_skills:
    plugins = home / ".claude" / "plugins"
    if plugins.is_dir():
        # Depth-capped walk (no unbounded **/ glob — plugin trees can be huge)
        skip_dir_names = {"node_modules", ".git", "__pycache__", "dist", "build"}
        for dirpath, dirnames, filenames in os.walk(plugins):
            if len(by_name) >= max_skills:
                break
            dirnames[:] = [d for d in dirnames if d not in skip_dir_names]
            rel = Path(dirpath).relative_to(plugins)
            if len(rel.parts) > 8:
                dirnames.clear()
                continue
            # Expect .../skills/<skill-name>/SKILL.md
            if rel.parts and rel.parts[-1] == "skills":
                continue
            if len(rel.parts) >= 2 and rel.parts[-2] == "skills" and "SKILL.md" in filenames:
                skill_md = Path(dirpath) / "SKILL.md"
                try:
                    text = skill_md.read_text(encoding="utf-8", errors="replace")
                except OSError:
                    continue
                meta = frontmatter(text)
                name = meta.get("name") or Path(dirpath).name
                if not re.match(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$", name):
                    continue
                if name in by_name:
                    continue
                desc = meta.get("description", "")[:1024]
                by_name[name] = {
                    "name": name,
                    "description": desc,
                    "path": str(skill_md.resolve()),
                    "source": "plugin",
                }

print(json.dumps(list(by_name.values()), ensure_ascii=False))
PY
