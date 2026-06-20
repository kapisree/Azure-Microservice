#!/usr/bin/env bash
# Verifies constitution.md has exactly 12 articles with unique slug fields matching ^art-[a-z0-9-]+$.
set -euo pipefail

FILE="constitution.md"
if [[ ! -f "$FILE" ]]; then
  echo "FAIL: $FILE missing"
  exit 1
fi

ARTICLE_COUNT=$(grep -cE '^## [IVX]+ — ' "$FILE" || true)
if [[ "$ARTICLE_COUNT" != "12" ]]; then
  echo "FAIL: expected 12 articles, found $ARTICLE_COUNT"
  exit 1
fi

SLUGS=$(grep -oE '^slug: art-[a-z0-9-]+$' "$FILE" || true)
SLUG_COUNT=$(echo "$SLUGS" | grep -c '^slug:' || true)
if [[ "$SLUG_COUNT" != "12" ]]; then
  echo "FAIL: expected 12 slug fields, found $SLUG_COUNT"
  exit 1
fi

DUPES=$(echo "$SLUGS" | sort | uniq -d || true)
if [[ -n "$DUPES" ]]; then
  echo "FAIL: duplicate slugs: $DUPES"
  exit 1
fi

BADS=$(echo "$SLUGS" | grep -vE '^slug: art-[a-z0-9-]+$' || true)
if [[ -n "$BADS" ]]; then
  echo "FAIL: invalid slug format: $BADS"
  exit 1
fi

echo "PASS: constitution.md has 12 articles with unique well-formed slugs"
