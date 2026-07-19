#!/usr/bin/env python3
"""Cheap initial routing hint for the adaptive loop.

The model may refine this after inspecting the repository. The classifier is
deliberately conservative: it only selects parallel mode when the prompt
strongly suggests multiple independent surfaces.
"""

import json
import re
import sys


def classify(prompt: str) -> dict:
    text = prompt.lower()
    words = re.findall(r"[a-z0-9_+-]+", text)
    parallel_terms = {
        "across", "all", "multiple", "migrate", "entire", "parallel",
        "frontend", "backend", "api", "database",
    }
    delegated_terms = {
        "implement", "feature", "refactor", "authentication", "authorization",
        "security", "architecture", "migration", "integration", "debug",
    }
    parallel_score = sum(term in words for term in parallel_terms)
    delegated_score = sum(term in words for term in delegated_terms)

    if (len(words) >= 28 and parallel_score >= 2) or (
        len(words) >= 12 and parallel_score >= 4
    ):
        complexity, mode = "complex", "parallel"
    elif len(words) >= 14 or delegated_score >= 1:
        complexity, mode = "medium", "delegated"
    else:
        complexity, mode = "simple", "direct"
    return {"complexity": complexity, "execution_mode": mode}


if __name__ == "__main__":
    prompt = " ".join(sys.argv[1:]).strip()
    if not prompt:
        raise SystemExit("usage: classify-task.py PROMPT")
    print(json.dumps(classify(prompt)))
