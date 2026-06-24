#!/usr/bin/env bash
# Governance test: the mechanical traceability chain (P3 of the 2026-06-09
# review). Delegates to scripts/check-traceability.sh and verifies supporting
# invariants: machine-readable annotations exist and the ANALYZE linkage
# check reports plans it skips instead of silently ignoring them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
pass() { echo "ok:   $1"; }

# 1. The traceability checker exists and passes.
if [[ -x scripts/check-traceability.sh ]]; then
  if bash scripts/check-traceability.sh; then
    pass "check-traceability.sh passes"
  else
    fail "check-traceability.sh reported violations"
  fi
else
  fail "scripts/check-traceability.sh missing"
fi

# 2. Every real proof carries a machine-readable Proves: header
#    (example.dfy is the documented placeholder and is exempt).
while IFS= read -r dfy; do
  [[ "$dfy" == "verification/example.dfy" ]] && continue
  if head -5 "$dfy" | grep -qE '// Proves: REQ-[0-9]{3}'; then
    pass "$dfy has Proves: header"
  else
    fail "$dfy missing '// Proves: REQ-NNN' header"
  fi
done < <(find verification -name '*.dfy' -type f)

# 3. The demo test file carries // Covers: annotations.
if grep -q '// Covers: REQ-' tests/DemoGreeting.Tests/GreetingTests.cs; then
  pass "demo tests carry // Covers: annotations"
else
  fail "tests/DemoGreeting.Tests/GreetingTests.cs has no // Covers: REQ-NNN annotations"
fi

# 4. The ANALYZE linkage check must name plans it skips (no silent skip).
if grep -q 'SKIP' scripts/analyze-adr-plan-linkage.sh; then
  pass "analyze-adr-plan-linkage.sh reports skipped plans"
else
  fail "analyze-adr-plan-linkage.sh silently skips plans without spec: frontmatter"
fi

if [[ $FAIL -ne 0 ]]; then
  echo "test_traceability: FAILED"
  exit 1
fi
echo "test_traceability: all checks passed"
