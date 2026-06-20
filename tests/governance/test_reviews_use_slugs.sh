#!/usr/bin/env bash
# Governance test (retro 2026-05-28 proposal #2, accepted): article citations
# anywhere in docs/ must use art-* slugs, never Roman numerals
# (art-naming-tagging). Exemptions: superseded specs and archived reviews
# (historical records), and the plans for superseded specs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

is_exempt() {
  local f="$1"
  case "$f" in
    docs/reviews/archive-*) return 0 ;;
  esac
  # Superseded specs are historical records.
  if head -20 "$f" 2>/dev/null | grep -q '^status: superseded'; then
    return 0
  fi
  return 1
}

VIOLATIONS=0
while IFS= read -r f; do
  is_exempt "$f" && continue
  if hits=$(grep -nE 'Articles? (XII|XI|IX|X|VIII|VII|VI|IV|V|III|II|I)\b' "$f"); then
    echo "FAIL: $f cites articles by Roman numeral:"
    echo "$hits" | sed 's/^/  /'
    VIOLATIONS=1
  fi
done < <(find docs -name '*.md' -type f)

if [[ $VIOLATIONS -ne 0 ]]; then
  echo "test_reviews_use_slugs: FAILED — cite by art-<kebab> slug (art-naming-tagging)"
  exit 1
fi
echo "PASS: all docs/ article citations use slugs (no Roman numerals)"
