#!/usr/bin/env bash
# Verifies .claude/rules/review-gate.md cites only article slugs that exist in constitution.md
# AND that it cites at least the five required slugs.
set -euo pipefail

CONST="constitution.md"
RULE=".claude/rules/review-gate.md"

if [[ ! -f "$CONST" ]] || [[ ! -f "$RULE" ]]; then
  echo "FAIL: missing $CONST or $RULE"
  exit 1
fi

REQUIRED=(art-branch-as-state art-review-gate art-kernel-boundary art-threat-driven-security art-release-readiness)
for slug in "${REQUIRED[@]}"; do
  if ! grep -q "$slug" "$RULE"; then
    echo "FAIL: $RULE does not cite required slug $slug"
    exit 1
  fi
done

EXISTING=$(grep -oE 'art-[a-z0-9-]+' "$CONST" | sort -u)
CITED=$(grep -oE 'art-[a-z0-9-]+' "$RULE" | sort -u)
for slug in $CITED; do
  if ! echo "$EXISTING" | grep -qx "$slug"; then
    echo "FAIL: $RULE cites $slug which does not exist in $CONST"
    exit 1
  fi
done

echo "PASS: review-gate.md cites only existing slugs and includes all required slugs"
