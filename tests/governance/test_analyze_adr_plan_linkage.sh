#!/usr/bin/env bash
# REQ-126: fixture test for scripts/analyze-adr-plan-linkage.sh (retro
# 2026-05-28 proposal #1 — "test the validator"), plus a live-repo run.
# Fixture cases:
#   A. valid linkage                      -> must PASS
#   B. [verifiable] REQ with no ADR      -> must FAIL
#   C. prose mentioning `[verifiable]` in backticks (the REQ-126 false-tag
#      bug found 2026-06-09)             -> must NOT count as a tag
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../../scripts/analyze-adr-plan-linkage.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/docs/specs" "$TMP/docs/plans" "$TMP/docs/adr"

cat > "$TMP/docs/specs/2026-01-01-fixture-design.md" <<'EOF'
---
type: spec
status: accepted
---
# Fixture spec
- **REQ-901:** [verifiable-model] A real tagged requirement.
- **REQ-902:** An untagged requirement; the checker walks any `[verifiable]` REQ — this backtick mention is prose, not a tag.
EOF

cat > "$TMP/docs/adr/001-fixture.md" <<'EOF'
---
id: ADR-901
status: accepted
addresses: [REQ-901]
---
# fixture ADR
EOF

cat > "$TMP/docs/plans/2026-01-01-fixture-plan.md" <<'EOF'
---
type: plan
spec: 2026-01-01-fixture
decisions: [ADR-901]
---
# fixture plan
EOF

FAIL=0
# Case A+C: REQ-901 covered; REQ-902's backtick mention must not need an ADR.
if LINKAGE_BASE_DIR="$TMP" bash "$SCRIPT" >/dev/null 2>&1; then
  echo "ok:   fixture A+C — valid linkage passes; backtick-quoted tag mention ignored"
else
  echo "FAIL: fixture A+C — valid fixture rejected (backtick prose counted as a tag?)"
  FAIL=1
fi

# Case B: drop the ADR coverage -> must fail.
sed -i.bak 's/addresses: \[REQ-901\]/addresses: []/' "$TMP/docs/adr/001-fixture.md"
if LINKAGE_BASE_DIR="$TMP" bash "$SCRIPT" >/dev/null 2>&1; then
  echo "FAIL: fixture B — uncovered [verifiable-model] REQ was not rejected"
  FAIL=1
else
  echo "ok:   fixture B — uncovered REQ correctly rejected"
fi

# Live repo run.
if bash "$SCRIPT"; then
  echo "ok:   live repo linkage check passes"
else
  echo "FAIL: live repo linkage check failed"
  FAIL=1
fi

[[ $FAIL -eq 0 ]] || { echo "test_analyze_adr_plan_linkage: FAILED"; exit 1; }
echo "test_analyze_adr_plan_linkage: all checks passed"
