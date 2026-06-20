#!/usr/bin/env bash
# Smoke test for scripts/run-quality-gates.sh: exits 0 on a clean repo.
set -euo pipefail

# Recursion guard: when this test is invoked by the orchestrator itself, the
# orchestrator sets SPECFLOW_QG_RUNNING=1 so the smoke test's own re-invocation
# of the orchestrator would otherwise recurse. We short-circuit here.
if [[ "${SPECFLOW_QG_RUNNING:-0}" == "1" ]]; then
  echo "SKIP: smoke test no-op inside orchestrator (recursion guard)"
  exit 0
fi

OUTPUT=$(bash scripts/run-quality-gates.sh 2>&1) || {
  echo "FAIL: script exited non-zero on clean repo"
  echo "$OUTPUT"
  exit 1
}

if ! echo "$OUTPUT" | grep -q 'All quality gates passed'; then
  echo "FAIL: script did not report success"
  echo "$OUTPUT"
  exit 1
fi

echo "PASS: run-quality-gates.sh exits 0 with success message on clean repo"
