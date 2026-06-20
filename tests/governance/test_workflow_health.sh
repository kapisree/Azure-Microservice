#!/usr/bin/env bash
# Governance test: the CI/verifier workflows must actually be able to run.
# Guards against a failure class where the gates pass vacuously:
# workflows that target a branch that does not exist, unrendered template
# placeholders, non-recursive Dafny discovery, and bash syntax errors —
# all of which would make every gate in art-review-gate silently unenforced.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
pass() { echo "ok:   $1"; }

WORKFLOWS=(.github/workflows/ci.yml .github/workflows/verifier.yml)

# Determine the default branch (fallback: main).
DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

# 1. Every workflow branch filter must reference the default branch.
for wf in "${WORKFLOWS[@]}"; do
  if grep -E '^\s*branches:' "$wf" | grep -qv "\b${DEFAULT_BRANCH}\b"; then
    fail "$wf has a branches: filter not targeting default branch '${DEFAULT_BRANCH}'"
  else
    pass "$wf branch filters target '${DEFAULT_BRANCH}'"
  fi
done

# 2. No unrendered {{...}} template placeholders in live workflows.
#    (GitHub Actions' own ${{ ... }} expressions are legitimate and excluded.)
for wf in "${WORKFLOWS[@]}"; do
  if grep -qE '(^|[^$])\{\{' "$wf"; then
    fail "$wf contains unrendered {{...}} placeholders"
  else
    pass "$wf has no template placeholders"
  fi
done

# 3. No redirection inside a for-loop word list (bash syntax error:
#    'for x in glob 2>/dev/null; do' fails 100% of the time).
for wf in "${WORKFLOWS[@]}"; do
  if grep -qE 'for\s+\w+\s+in\s+[^;]*2>/dev/null' "$wf"; then
    fail "$wf has redirection inside a for-loop word list (bash syntax error)"
  else
    pass "$wf has no for-loop redirection syntax error"
  fi
done

# 4. Dafny discovery in workflows must be recursive (proofs live in
#    verification/<subdir>/; a bare 'verification/*.dfy' glob misses them all).
if grep -qE 'dafny verify verification/\*\.dfy' .github/workflows/verifier.yml; then
  fail "verifier.yml uses non-recursive 'verification/*.dfy' — misses all proofs in subdirectories"
else
  pass "verifier.yml Dafny discovery is not the known non-recursive glob"
fi

# 5. Some workflow must run the quality-gates orchestrator on PRs,
#    otherwise the gates are local-honor-system only.
if grep -q 'run-quality-gates.sh' .github/workflows/ci.yml; then
  pass "ci.yml runs scripts/run-quality-gates.sh"
else
  fail "ci.yml does not run scripts/run-quality-gates.sh — quality gates unenforced in CI"
fi

# 6. The verifier must trigger on normally-opened PRs, not only
#    ready_for_review/labeled (a PR opened non-draft never fires those).
if grep -qE '^\s*types:.*\bopened\b' .github/workflows/verifier.yml && \
   grep -qE '^\s*types:.*\bsynchronize\b' .github/workflows/verifier.yml; then
  pass "verifier.yml triggers on opened + synchronize"
else
  fail "verifier.yml does not trigger on opened/synchronize — non-draft PRs are never verified"
fi

# 7. Tooling dependencies used by the gates must be declared.
for dep in pytest anthropic; do
  if grep -qi "^${dep}" scripts/requirements.txt; then
    pass "scripts/requirements.txt declares ${dep}"
  else
    fail "scripts/requirements.txt missing '${dep}' — quality gates fail on a clean checkout"
  fi
done

if [[ $FAIL -ne 0 ]]; then
  echo "test_workflow_health: FAILED"
  exit 1
fi
echo "test_workflow_health: all checks passed"
