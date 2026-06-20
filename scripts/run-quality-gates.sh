#!/usr/bin/env bash
# Orchestrates: pytest, Dafny verification, governance tests, optional per-stack hook.
# Used by VALIDATE and again in RELEASE. Treats absence of a category as pass.
# Implements the quality-gate exit semantics (art-formal-verification, art-release-readiness).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Recursion guard: governance tests glob includes any test_*.sh, and the smoke
# test for THIS orchestrator re-invokes it. Export a sentinel so the smoke
# test can short-circuit when it sees itself running inside us.
export SPECFLOW_QG_RUNNING=1

FAIL=0
SECTION() { printf '\n=== %s ===\n' "$1"; }

# 1. Python tests
SECTION "Python tests (pytest)"
if [[ -d tests ]] && find tests -type f -name 'test_*.py' | grep -q .; then
  if python -m pytest tests/ -q; then
    echo "PASS pytest"
  else
    echo "FAIL pytest"
    FAIL=1
  fi
else
  echo "SKIP pytest (no test_*.py files)"
fi

# 2. Dafny verification
# Policy: if .dfy files exist but dafny is not installed, this is a hard fail
# (missing dependency), not a skip. Absence of the tool with proofs present
# silently passing would violate art-formal-verification.
SECTION "Dafny verification"
if find verification -type f -name '*.dfy' 2>/dev/null | grep -q .; then
  if command -v dafny >/dev/null 2>&1; then
    if dafny verify $(find verification -name '*.dfy'); then
      echo "PASS dafny"
    else
      echo "FAIL dafny"
      FAIL=1
    fi
  else
    echo "FAIL dafny (binary not installed but .dfy files present — install Dafny or remove proofs)"
    FAIL=1
  fi
else
  echo "SKIP dafny (no .dfy files)"
fi

# 3. Governance tests
SECTION "Governance tests"
if [[ -d tests/governance ]] && find tests/governance -type f -name 'test_*.sh' | grep -q .; then
  for t in tests/governance/test_*.sh; do
    if bash "$t"; then
      echo "PASS $t"
    else
      echo "FAIL $t"
      FAIL=1
    fi
  done
else
  echo "SKIP governance (no test_*.sh files)"
fi

# 4. Per-stack hook (optional)
SECTION "Per-stack hook"
HOOK="scripts/quality-gates-$(cat .stack 2>/dev/null || echo none).sh"
if [[ -x "$HOOK" ]]; then
  if "$HOOK"; then
    echo "PASS $HOOK"
  else
    echo "FAIL $HOOK"
    FAIL=1
  fi
else
  echo "SKIP per-stack hook ($HOOK not present or not executable)"
fi

SECTION "Summary"
if [[ $FAIL -eq 0 ]]; then
  echo "All quality gates passed"
  exit 0
fi
echo "One or more gates failed"
exit 1
