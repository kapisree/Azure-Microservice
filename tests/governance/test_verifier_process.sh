#!/usr/bin/env bash
# Governance test: the verifier review process must be subscription-based
# (run locally via `claude -p`), not API-key-billed CI automation.
# Decision record: PR #9 discussion, 2026-06-09 — the team uses Claude Code
# subscriptions; the cloud verifier jobs were replaced by scripts/run-verifier.sh
# plus a CI attestation check that findings were posted to the PR.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
pass() { echo "ok:   $1"; }

# 1. The verifier runner script exists, is executable, and parses.
if [[ -x scripts/run-verifier.sh ]] && bash -n scripts/run-verifier.sh; then
  pass "scripts/run-verifier.sh exists, executable, syntax OK"
else
  fail "scripts/run-verifier.sh missing, not executable, or has syntax errors"
fi

# 2. The script must refuse to run inside a Claude Code session
#    (a Claude session cannot spawn another Claude session).
if grep -q 'CLAUDECODE' scripts/run-verifier.sh 2>/dev/null; then
  pass "run-verifier.sh guards against running inside a Claude Code session"
else
  fail "run-verifier.sh has no CLAUDECODE session guard"
fi

# 3. The script invokes headless Claude (claude -p).
if grep -qE 'claude .*-p|claude -p' scripts/run-verifier.sh 2>/dev/null; then
  pass "run-verifier.sh invokes claude -p"
else
  fail "run-verifier.sh does not invoke claude -p"
fi

# 4. CI must not depend on API-key billing for verification.
if grep -q 'ANTHROPIC_API_KEY' .github/workflows/verifier.yml; then
  fail "verifier.yml still references ANTHROPIC_API_KEY — CI must not require API billing"
else
  pass "verifier.yml has no ANTHROPIC_API_KEY dependency"
fi

# 5. CI must check that verifier findings were posted to the PR
#    (attestation — otherwise the local verifier is an honor system).
if grep -q 'specflow-verifier' .github/workflows/verifier.yml; then
  pass "verifier.yml checks for the specflow-verifier findings marker"
else
  fail "verifier.yml has no attestation check for posted verifier findings"
fi

# 6. The operational rule documents the new process.
if grep -q 'run-verifier.sh' .claude/rules/review-gate.md; then
  pass "review-gate.md documents scripts/run-verifier.sh"
else
  fail "review-gate.md does not document the run-verifier.sh process"
fi

if [[ $FAIL -ne 0 ]]; then
  echo "test_verifier_process: FAILED"
  exit 1
fi
echo "test_verifier_process: all checks passed"
