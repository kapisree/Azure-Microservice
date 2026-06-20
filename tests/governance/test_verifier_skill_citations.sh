#!/usr/bin/env bash
# REQ-127: Verifies .claude/skills/verifier/SKILL.md contains a Citation Discipline
# section that specifies the prefix format [<art-slug>] and references constitution.md
# as the slug source. Catches drift if a maintainer weakens the citation rule.
set -euo pipefail

FILE=".claude/skills/verifier/SKILL.md"
if [[ ! -f "$FILE" ]]; then
  echo "FAIL: $FILE missing"
  exit 1
fi

if ! grep -q '^## Citation Discipline' "$FILE"; then
  echo "FAIL: $FILE missing '## Citation Discipline' section"
  exit 1
fi

if ! grep -q '\[<art-slug>\]' "$FILE"; then
  echo "FAIL: $FILE Citation Discipline must specify prefix format [<art-slug>]"
  exit 1
fi

if ! grep -q 'constitution.md' "$FILE"; then
  echo "FAIL: $FILE Citation Discipline must reference constitution.md"
  exit 1
fi

echo "PASS: verifier skill cites discipline + constitution.md"
