#!/usr/bin/env bash
# verify-doc.sh -- Lightweight structural checker for spec/plan markdown.
# Called by PostToolUse hook. No AI calls -- pure text checks.
# Outputs warnings to stdout so the agent sees them immediately.
set -euo pipefail

FILE="${1:-}"
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

WARNINGS=()
CONTENT=$(cat "$FILE")
DIR=$(dirname "$FILE")

# Check 1: YAML frontmatter present
if ! echo "$CONTENT" | head -1 | grep -q '^---$'; then
  WARNINGS+=("WARN: missing YAML frontmatter in $FILE")
fi

# Check 2: Placeholder markers (TBD, TODO, {{...}})
placeholder_hits=$(grep -n -i -E '(\bTBD\b|\bTODO\b|\{\{[^}]+\}\})' "$FILE" 2>/dev/null || true)
if [ -n "$placeholder_hits" ]; then
  while IFS= read -r line_num_and_text; do
    line_num=$(echo "$line_num_and_text" | cut -d: -f1)
    WARNINGS+=("WARN: placeholder found at $FILE:$line_num")
  done <<< "$placeholder_hits"
fi

# Check 3: Relative markdown links resolve
link_hits=$(grep -oE '\[[^]]+\]\([^)]+\)' "$FILE" 2>/dev/null || true)
if [ -n "$link_hits" ]; then
  while IFS= read -r match; do
    link_path=$(echo "$match" | sed -E 's/.*\]\(([^)]+)\).*/\1/')
    # Skip URLs, anchors, and non-relative paths
    case "$link_path" in
      http://*|https://*) continue ;;
      \#*) continue ;;
      /*) continue ;;
    esac
    # Strip fragment anchor (#section) before resolving
    link_path_no_fragment="${link_path%%#*}"
    # Resolve relative to the file's directory
    resolved="$DIR/$link_path_no_fragment"
    if [ ! -f "$resolved" ]; then
      WARNINGS+=("WARN: broken link [$link_path] in $FILE -- target does not exist")
    fi
  done <<< "$link_hits"
fi

# Check 4: Required sections based on doc type (from frontmatter or path)
DOC_TYPE=""
if echo "$CONTENT" | head -10 | grep -q "^type:"; then
  DOC_TYPE=$(echo "$CONTENT" | head -10 | grep "^type:" | head -1 | sed 's/type:[[:space:]]*//')
fi
if [ -z "$DOC_TYPE" ]; then
  case "$FILE" in
    */specs/*) DOC_TYPE="spec" ;;
    */plans/*) DOC_TYPE="plan" ;;
  esac
fi

if [ "$DOC_TYPE" = "spec" ]; then
  for section in "## Overview" "## Problem Statement" "## User Personas" "## Functional Requirements"; do
    if ! echo "$CONTENT" | grep -q "^$section"; then
      WARNINGS+=("WARN: missing required section '$section' in spec $FILE")
    fi
  done
elif [ "$DOC_TYPE" = "plan" ]; then
  heading_count=$(echo "$CONTENT" | grep -c "^## " || true)
  if [ "$heading_count" -lt 1 ]; then
    WARNINGS+=("WARN: plan $FILE has no section headings")
  fi
fi

# Output all warnings
for w in "${WARNINGS[@]+"${WARNINGS[@]}"}"; do
  echo "$w"
done
