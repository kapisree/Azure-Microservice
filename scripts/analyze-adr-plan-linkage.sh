#!/usr/bin/env bash
# REQ-126: Walks docs/plans/*.md frontmatter and docs/adr/*.md frontmatter,
# exits non-zero if any [verifiable]/[verifiable-model] REQ in a plan's source spec
# lacks an accepted ADR in the plan's decisions: field whose addresses: includes it.
# art-formal-verification, art-kernel-boundary.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# LINKAGE_BASE_DIR lets the fixture test point the walker at synthetic docs.
cd "${LINKAGE_BASE_DIR:-$ROOT}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 required for ANALYZE check"
  exit 2
fi

python3 - <<'PY'
import os, re, sys, glob

def parse_frontmatter(path):
    text = open(path).read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
    return fm

def parse_list(s):
    s = s.strip().strip("[]")
    if not s:
        return []
    return [x.strip() for x in s.split(",")]

def verifiable_reqs(spec_path):
    if not os.path.exists(spec_path):
        return []
    body = open(spec_path).read()
    # Match: - **REQ-NNN:** ... [verifiable] / [verifiable-model]
    # Colon may be inside the bold span ("**REQ-200:**") or after ("**REQ-200**:").
    # A backtick-quoted `[verifiable]` is prose ABOUT the tag, not a tag —
    # REQ-126's own description mentions it (false-positive bug, 2026-06-09).
    return re.findall(r"\*\*REQ-(\d{3,}):?\*\*[^\n]*(?<!`)\[verifiable(?:-model)?\](?!`)", body)

# Collect ADRs
adrs = {}
for p in sorted(glob.glob("docs/adr/*.md")):
    fm = parse_frontmatter(p)
    aid = fm.get("id", "").strip()
    if not aid:
        continue
    adrs[aid] = {
        "status": fm.get("status", "").strip(),
        "addresses": parse_list(fm.get("addresses", "")),
        "path": p,
    }

# Walk plans
errors = []
checked = 0
skipped = []
for plan_path in sorted(glob.glob("docs/plans/*.md")):
    fm = parse_frontmatter(plan_path)
    spec_slug = fm.get("spec", "").strip()
    if not spec_slug:
        # No silent skips: a plan without spec: frontmatter escapes this
        # gate entirely — say so every run (2026-06-09 review, Theme 6).
        skipped.append(plan_path)
        continue
    decisions = parse_list(fm.get("decisions", ""))
    spec_path = f"docs/specs/{spec_slug}-design.md"
    reqs = verifiable_reqs(spec_path)
    if not reqs:
        continue
    checked += 1
    for req in reqs:
        req_id = f"REQ-{req}"
        covered = False
        for adr_id in decisions:
            adr = adrs.get(adr_id)
            if adr and adr["status"] == "accepted" and req_id in adr["addresses"]:
                covered = True
                break
        if not covered:
            errors.append(f"  {plan_path}: {req_id} not covered by any accepted ADR in decisions: {decisions}")

for p in skipped:
    print(f"SKIP (no spec: frontmatter — outside the gate): {p}")

if errors:
    print("FAIL: ADR-PLAN linkage check (REQ-126):")
    for e in errors:
        print(e)
    sys.exit(1)

print(f"PASS: ADR-PLAN linkage check (REQ-126) — {checked} plan(s) verified, {len(skipped)} skipped")
PY
