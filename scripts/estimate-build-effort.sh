#!/usr/bin/env bash
# Project-level build-effort estimator (value function).
# Usage:
#   bash scripts/estimate-build-effort.sh [PRD.md] [PTR.md] ["optional user intent"]
#   bash scripts/estimate-build-effort.sh --write   # also persist into loop.json
#
# Reads PRD/PTR (+ optional free-text intent). Scores how "generic / known pattern"
# vs "novel / multi-phase / high-risk" the build is, then recommends a tier:
#   fast      — thin docs, outcome-first building (still VALIDATE + REVIEW + SECURITY)
#   standard  — normal harness
#   rigorous  — full harness, more ADRs, careful multi-phase roadmap
#
# Override: HARNESS_BUILD_EFFORT_TIER=fast|standard|rigorous
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

WRITE=0
ARGS=()
for a in "$@"; do
  if [ "$a" = "--write" ]; then WRITE=1
  else ARGS+=("$a")
  fi
done

PRD="${ARGS[0]:-PRD.md}"
PTR="${ARGS[1]:-PTR.md}"
INTENT="${ARGS[2]:-}"

OVERRIDE="${HARNESS_BUILD_EFFORT_TIER:-}"

python3 - "$PRD" "$PTR" "$INTENT" "$WRITE" "$OVERRIDE" <<'PY'
import json, os, re, sys
from pathlib import Path
from datetime import datetime, timezone

prd_path, ptr_path, intent, write_s, override = sys.argv[1:6]
write = write_s == "1"

def read(p):
    path = Path(p)
    if not path.is_file():
        return ""
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""

text = "\n".join([read(prd_path), read(ptr_path), intent or ""]).lower()
raw_len = len(text)

# --- signal dictionaries (substring / phrase match) ---
# Negative = pulls toward "fast" (generic, well-trodden agent territory)
FAST_SIGNALS = [
    (r"\bcli\b", 8, "cli"),
    (r"\btodo\b", 10, "todo_app"),
    (r"\bcrud\b", 10, "crud"),
    (r"\brest api\b|\bhttp api\b|\bjson api\b", 8, "rest_api"),
    (r"\bcall an api\b|\bfetch (from )?api\b|\bwrapper (around|for)\b", 10, "api_wrapper"),
    (r"\be-?commerce\b|\bshop(ping)? cart\b|\bproduct catalog\b", 6, "typical_ecommerce"),
    (r"\bblog\b|\bstatic site\b|\blanding page\b", 8, "static_or_blog"),
    (r"\bhello world\b|\bsample app\b|\bmvp\b|\bprototype\b", 6, "mvp_prototype"),
    (r"\bsingle[- ]file\b|\bno database\b|\bfile[- ]backed\b|\blocal[- ]only\b", 6, "local_simple"),
    (r"\bchecklist\b|\bform validation\b|\bcrud api\b", 6, "boilerplate"),
]

# Positive = pulls toward "rigorous"
HARD_SIGNALS = [
    (r"\bgta\b|\bvice city\b|\bgame (engine|clone)\b|\bunreal\b|\bunity\b|\b3d (engine|world)\b", 22, "game_engine_clone"),
    (r"\btrain(ing)? (an? )?(llm|language model)\b|\bfrom[- ]scratch (llm|model)\b|\bpretrain", 24, "train_llm"),
    (r"\bproductionize\b|\bproduction[- ]ready\b|\bmulti[- ]region\b|\bhigh availability\b|\bsla\b", 12, "productionize"),
    (r"\bpublish (to )?(app store|play store|npm|pypi|crates\.io)\b|\bmarketplace\b", 8, "publish_distribute"),
    (r"\breal[- ]?time\b|\bmultiplayer\b|\bwebsocket scale\b|\bdistributed (system|consensus)\b", 14, "realtime_distributed"),
    (r"\bkubernetes\b|\bmulti[- ]tenant\b|\bsaas platform\b|\bbilling\b|\bstripe connect\b", 12, "platform_saas"),
    (r"\bpayments?\b|\bpci\b|\bhipaa\b|\bgdpr\b|\bcompliance\b|\bauthz\b|\bsso\b|\boauth\b", 10, "security_compliance"),
    (r"\bcompiler\b|\boperating system\b|\bdatabase engine\b|\bblockchain\b|\bzk[- ]?snark\b", 18, "systems_deep"),
    (r"\bmachine learning pipeline\b|\bmlops\b|\bmodel serving\b|\binference cluster\b", 12, "ml_platform"),
    (r"\bmigration\b|\blegacy rewrite\b|\bbrownfield modernization\b", 8, "legacy_rewrite"),
]

matched_fast = []
matched_hard = []
score = 45  # baseline "standard"

for pat, w, name in FAST_SIGNALS:
    if re.search(pat, text):
        score -= w
        matched_fast.append({"signal": name, "weight": -w})

for pat, w, name in HARD_SIGNALS:
    if re.search(pat, text):
        score += w
        matched_hard.append({"signal": name, "weight": w})

# Structure heuristics
milestone_hits = len(re.findall(r"\bmilestone\b|\bphase\s*\d|\bepic\b", text))
if milestone_hits >= 4:
    score += 8
    matched_hard.append({"signal": "many_phases", "weight": 8})
elif milestone_hits >= 2:
    score += 4
    matched_hard.append({"signal": "multi_phase", "weight": 4})

# Long requirements → more coordination cost
if raw_len > 12000:
    score += 10
    matched_hard.append({"signal": "long_spec", "weight": 10})
elif raw_len > 6000:
    score += 5
    matched_hard.append({"signal": "medium_spec", "weight": 5})
elif 0 < raw_len < 800 and matched_fast:
    score -= 5
    matched_fast.append({"signal": "short_spec", "weight": -5})

# Integration fan-out
integrations = len(re.findall(
    r"\bintegrat(e|ion)\b|\bthird[- ]party\b|\bwebhook\b|\bkafka\b|\bredis\b|\bpostgres\b|\bmongodb\b",
    text,
))
if integrations >= 5:
    score += 8
    matched_hard.append({"signal": "many_integrations", "weight": 8})
elif integrations >= 3:
    score += 4
    matched_hard.append({"signal": "several_integrations", "weight": 4})

score = max(0, min(100, score))

def tier_for(s):
    if s < 35:
        return "fast"
    if s < 65:
        return "standard"
    return "rigorous"

tier = tier_for(score)
override_used = None
if override in ("fast", "standard", "rigorous"):
    override_used = override
    tier = override

docs_profile = {
    "fast": "thin",
    "standard": "normal",
    "rigorous": "full",
}[tier]

profiles = {
    "fast": {
        "bootstrap_docs": "Minimal: CLAUDE.md mission/stack, short ROADMAP (2–4 outcomes), thin ARCHITECTURE + one ADR if stack choice is non-obvious. Skip filling every template with prose.",
        "build_style": "Outcome-first after bootstrap. Prefer implementing user-visible results; avoid markdown scaffolding churn between iterations.",
        "planner": "Short plans tied to user outcomes. Merge related modules into fewer roadmap items.",
        "architect": "Only for non-obvious stack choices or security boundaries.",
        "gate1": "Keep; may be brief for low-risk slices. Never skip.",
        "always": ["validate", "review", "security"],
    },
    "standard": {
        "bootstrap_docs": "Normal docs set; coarse ROADMAP (3–6 items).",
        "build_style": "Balanced plan→build→validate→review per LOOP.md.",
        "planner": "Full AGENT_TASK; Task Graph when needed.",
        "architect": "On large / cross-cutting tasks.",
        "gate1": "Full human approval.",
        "always": ["validate", "review", "security"],
    },
    "rigorous": {
        "bootstrap_docs": "Full docs + ADRs for major decisions; careful multi-phase ROADMAP; explicit risks in PROJECT_STATE.",
        "build_style": "Do not rush. Prefer correctness, security, and phased delivery over speed.",
        "planner": "Detailed plans; expect Task Graphs; architect before large slices.",
        "architect": "Early and often for boundaries, scale, and threat model.",
        "gate1": "Strict; challenge under-scoped plans.",
        "always": ["validate", "review", "security"],
    },
}

recommendation = profiles[tier]
value = {
    "formula": "score = 45 + Σ(hard_weights) - Σ(fast_weights) + structure_bonuses; clamp 0..100",
    "interpretation": (
        "Lower score → generic / previously solved by many agents → build faster with thin docs. "
        "Higher score → novel, multi-phase, or high-risk → full harness rigor."
    ),
    "thresholds": {"fast": "<35", "standard": "35–64", "rigorous": "≥65"},
}

out = {
    "ok": True,
    "score": score,
    "tier": tier,
    "docs_profile": docs_profile,
    "override": override_used,
    "matched_fast": matched_fast,
    "matched_hard": matched_hard,
    "recommendation": recommendation,
    "value_function": value,
    "invariants": [
        "VALIDATE is always a hard gate",
        "REVIEWER runs every iteration before GATE 2",
        "SECURITY runs every iteration (light pass OK on pure docs; full OWASP when auth/data/network/payments/uploads)",
        "Never skip GATE 1/2; never use bypassPermissions as project default",
    ],
    "examples": {
        "fast": ["simple CLI", "todo app", "typical ecommerce CRUD", "call/wrap an API"],
        "rigorous": ["GTA Vice City clone", "train + productionize an LLM", "publish a multi-tenant SaaS platform"],
    },
    "sources": {"prd": prd_path, "ptr": ptr_path, "intent_chars": len(intent or "")},
    "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}

print(json.dumps(out, indent=2, ensure_ascii=False))

if write:
    state_dir = Path(".claude/state")
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / "build_effort.json").write_text(
        json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    loop_path = state_dir / "loop.json"
    loop = {}
    if loop_path.is_file():
        try:
            loop = json.loads(loop_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            loop = {}
    loop["build_effort_tier"] = tier
    loop["build_effort_score"] = score
    loop["docs_profile"] = docs_profile
    loop_path.write_text(json.dumps(loop, indent=2) + "\n", encoding="utf-8")
PY

# Best-effort event (ignore failure if script missing mid-bootstrap)
if [ "$WRITE" = "1" ]; then
  bash scripts/loop-event.sh build_effort_estimate '{}' >/dev/null 2>&1 || true
fi
