#!/usr/bin/env bash
# Governance test: spec lifecycle + constitution/spec consistency (P2 of the
# 2026-06-09 review). Guards: every spec carries a status; superseded specs
# say what superseded them; the constitution defines every verification tag
# actually in use; review-gate.md states the same RELEASE gate as the
# constitution.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
pass() { echo "ok:   $1"; }

# 1. Every spec has YAML frontmatter with a valid status.
for f in docs/specs/*.md; do
  if [[ "$(head -1 "$f")" != "---" ]]; then
    fail "$f has no YAML frontmatter"
    continue
  fi
  status=$(awk '/^---$/{n++; next} n==1 && /^status:/{print $2; exit}' "$f")
  case "$status" in
    draft|accepted|superseded) pass "$f status: $status" ;;
    *) fail "$f has invalid/missing status: '$status'" ;;
  esac
  if [[ "$status" == "superseded" ]]; then
    sup=$(awk '/^---$/{n++; next} n==1 && /^superseded_by:/{print $2; exit}' "$f")
    if [[ -n "$sup" && "$sup" != '""' ]]; then
      pass "$f names superseded_by"
    else
      fail "$f is superseded but superseded_by is empty"
    fi
  fi
done

# 2. The constitution defines [verifiable-model] — the tag in actual use.
if grep -q 'verifiable-model' constitution.md; then
  pass "constitution defines [verifiable-model]"
else
  fail "constitution does not define [verifiable-model] (every tagged REQ in the repo uses it)"
fi

# 3. review-gate.md RELEASE gate matches the constitution: annotated-tag
#    fallback and manifest transcription must both be stated.
if grep -A3 'RELEASE exit gate' .claude/rules/review-gate.md | grep -q 'fallback' && \
   grep -A3 'RELEASE exit gate' .claude/rules/review-gate.md | grep -q 'transcribed'; then
  pass "review-gate RELEASE gate states fallback + manifest transcription"
else
  fail "review-gate RELEASE gate missing annotated-fallback or manifest-transcription clause (would fail the compliant v0.0.1-demo)"
fi

# 4. review-gate back-edge has the spec's 6 steps.
steps=$(awk '/## Back-edge protocol/,/## Minor exception/' .claude/rules/review-gate.md | grep -cE '^[0-9]+\.')
if [[ "$steps" -eq 6 ]]; then
  pass "review-gate back-edge has 6 steps"
else
  fail "review-gate back-edge has $steps steps (spec REQ-102 mandates 6)"
fi

# 5. The /retrospective command requires recording decisions on prior
#    proposals (closes the art-retrospective-cadence loop).
if grep -qi 'decision' .claude/commands/retrospective.md; then
  pass "/retrospective requires proposal decisions"
else
  fail "/retrospective never records accept/reject decisions — the retro loop stays half-closed"
fi

# 6. The spec template must use reserved placeholder IDs (REQ-XXX), not
#    real-looking IDs that collide with the globally-unique namespace.
if grep -qE '\*\*REQ-00[0-9]' schemas/spec-template.md; then
  fail "spec template uses REQ-00N placeholders that collide with real globally-unique IDs"
else
  pass "spec template placeholders don't collide with real REQ IDs"
fi

if [[ $FAIL -ne 0 ]]; then
  echo "test_spec_lifecycle: FAILED"
  exit 1
fi
echo "test_spec_lifecycle: all checks passed"
