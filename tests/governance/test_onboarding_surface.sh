#!/usr/bin/env bash
# Governance test: the onboarding surface (README, init-project.sh, rules)
# must describe the CURRENT pipeline, and stale template copies must not exist.
# Guards the failure class from the 2026-06-09 review (Theme 3): README frozen
# at v3, init-project.sh at v2, a scaffold copy a full version behind, and the
# TDD rule not session-loaded.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
pass() { echo "ok:   $1"; }

# 1. README names all 10 phases.
MISSING=""
for phase in BRAINSTORM SPECIFY ARCHITECTURE PLAN TASKS ANALYZE IMPLEMENT VALIDATE SECURITY RELEASE; do
  grep -q "$phase" README.md || MISSING="$MISSING $phase"
done
if [[ -z "$MISSING" ]]; then
  pass "README names all 10 phases"
else
  fail "README missing phases:$MISSING"
fi

# 2. README documents the enforcement and verifier tooling.
for s in run-quality-gates.sh run-verifier.sh analyze-adr-plan-linkage.sh; do
  if grep -q "$s" README.md; then pass "README mentions $s"; else fail "README does not mention $s"; fi
done

# 3. Correct skill name everywhere on the onboarding surface
#    (/superpowers:brainstorm does not exist; it is :brainstorming).
if grep -rnE 'superpowers:brainstorm([^i]|$)' README.md scripts/init-project.sh templates/ 2>/dev/null; then
  fail "stale skill name 'superpowers:brainstorm' (must be 'brainstorming')"
else
  pass "no stale 'superpowers:brainstorm' skill references"
fi

# 4. The stale scaffold copies must not exist — this repo IS the template.
if [[ -e specflow-scaffold || -e specflow-scaffold.zip ]]; then
  fail "specflow-scaffold/ or specflow-scaffold.zip still exists (frozen at v3 — delete; decision 2026-06-09)"
else
  pass "no specflow-scaffold copies"
fi

# 5. No stale root-level rule duplicates; the real rules live in .claude/rules/.
if [[ -e review-gate.md || -e tdd.md ]]; then
  fail "stale root-level review-gate.md/tdd.md exist (shadow .claude/rules/)"
else
  pass "no stale root rule duplicates"
fi
if [[ -f .claude/rules/tdd.md ]] && grep -q 'art-test-first' .claude/rules/tdd.md; then
  pass ".claude/rules/tdd.md exists and cites art-test-first"
else
  fail ".claude/rules/tdd.md missing or does not cite art-test-first"
fi

# 6. init-project.sh is v3.1-aware: creates every artifact directory the
#    10-phase pipeline writes to, and writes the .stack file the quality
#    gates and release hook depend on.
for d in docs/adr docs/architecture docs/security docs/releases docs/retrospectives tests/governance; do
  if grep -q "$d" scripts/init-project.sh; then
    pass "init-project.sh creates $d"
  else
    fail "init-project.sh does not create $d"
  fi
done
if grep -q '\.stack' scripts/init-project.sh; then
  pass "init-project.sh writes .stack"
else
  fail "init-project.sh never writes .stack (RELEASE hook will fail months later)"
fi
if grep -qi 'v3\.1' scripts/init-project.sh && ! grep -q 'SpecFlow v2' scripts/init-project.sh; then
  pass "init-project.sh identifies as v3.1"
else
  fail "init-project.sh still identifies as v2/v3"
fi

if [[ $FAIL -ne 0 ]]; then
  echo "test_onboarding_surface: FAILED"
  exit 1
fi
echo "test_onboarding_surface: all checks passed"
