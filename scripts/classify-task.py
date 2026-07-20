#!/usr/bin/env python3
"""Signal-score task classifier for the adaptive loop.

Each routing tier has explicit signal sets. The classifier fires the first
matching tier in priority order (parallel → direct → delegated) and always
returns a non-empty routing_reason so setup-loop.sh can persist it.

Conservative parallel threshold: requires ≥2 distinct multi-surface terms
AND a minimum word count to avoid false positives on short prompts.
"""

import json
import re
import sys

# Signals that indicate simple, local edits → direct
DIRECT_SIGNALS = {
    "typo", "rename", "wording", "comment", "formatting", "format",
    "spelling", "indent", "whitespace", "cleanup", "tidy", "reword",
}

# Signals that indicate medium feature/refactor work → delegated
DELEGATED_SIGNALS = {
    "implement", "feature", "refactor", "authentication", "authorization",
    "security", "architecture", "migration", "integration", "debug",
    "debugging", "add", "build", "create", "develop", "update",
    "upgrade", "optimize", "performance", "test", "tests",
}

# Signals that indicate multi-surface work → parallel (conservative)
PARALLEL_SIGNALS = {
    "frontend", "backend", "api", "database", "across", "multiple",
    "migrate", "entire", "parallel", "services", "microservices",
    "fullstack", "infrastructure", "all",
}

# Parallel requires this many distinct surface signals
PARALLEL_MIN_SIGNALS = 2
# Parallel also requires a minimum prompt length (words)
PARALLEL_MIN_WORDS = 12
# Prompts at or below this word count stay direct unless delegated signals fire
DIRECT_MAX_WORDS = 8


def classify(prompt: str) -> dict:
    text = prompt.lower()
    words = re.findall(r"[a-z0-9_+\-]+", text)
    word_count = len(words)
    word_set = set(words)

    direct_hits = [t for t in sorted(DIRECT_SIGNALS) if t in word_set]
    delegated_hits = [t for t in sorted(DELEGATED_SIGNALS) if t in word_set]
    parallel_hits = [t for t in sorted(PARALLEL_SIGNALS) if t in word_set]

    parallel_score = len(parallel_hits)
    delegated_score = len(delegated_hits)

    # ── Parallel: multi-surface + length gate (conservative) ──────────────
    if word_count >= PARALLEL_MIN_WORDS and parallel_score >= PARALLEL_MIN_SIGNALS:
        surfaces = ", ".join(parallel_hits[:3])
        return {
            "complexity": "complex",
            "execution_mode": "parallel",
            "routing_reason": (
                f"multi-surface signals [{surfaces}] with {word_count} words"
            ),
        }

    # ── Direct: short prompt, no delegated signal, no multi-surface ────────
    if (
        word_count <= DIRECT_MAX_WORDS
        and delegated_score == 0
        and parallel_score < PARALLEL_MIN_SIGNALS
    ):
        if direct_hits:
            reason = f"simple-edit signals [{', '.join(direct_hits[:3])}]"
        else:
            reason = f"short prompt ({word_count} words), no complexity signals"
        return {
            "complexity": "simple",
            "execution_mode": "direct",
            "routing_reason": reason,
        }

    # ── Delegated: feature/refactor signals or longer prompt ──────────────
    if delegated_score >= 1 or word_count > DIRECT_MAX_WORDS:
        if delegated_hits:
            reason = (
                f"feature/refactor signals [{', '.join(delegated_hits[:3])}]"
            )
        else:
            reason = f"prompt length ({word_count} words) suggests medium work"
        return {
            "complexity": "medium",
            "execution_mode": "delegated",
            "routing_reason": reason,
        }

    # ── Fallback: direct for ambiguous short prompts ──────────────────────
    return {
        "complexity": "simple",
        "execution_mode": "direct",
        "routing_reason": f"no complexity signals, short prompt ({word_count} words)",
    }


if __name__ == "__main__":
    prompt = " ".join(sys.argv[1:]).strip()
    if not prompt:
        raise SystemExit("usage: classify-task.py PROMPT")
    print(json.dumps(classify(prompt)))
