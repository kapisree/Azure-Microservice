#!/usr/bin/env bash
# Tests for scripts/verify-doc.sh structural checker
set -euo pipefail
PASS=0; FAIL=0

assert_output_contains() {
  local desc="$1" file="$2" expected="$3"
  output=$(bash scripts/verify-doc.sh "$file" 2>&1 || true)
  if echo "$output" | grep -q "$expected"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
    echo "  Expected output to contain: $expected"
    echo "  Got: $output"
  fi
}

assert_no_output() {
  local desc="$1" file="$2"
  output=$(bash scripts/verify-doc.sh "$file" 2>&1 || true)
  if [ -z "$output" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
    echo "  Expected no output, got: $output"
  fi
}

# Setup temp dir
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Test 1: Missing frontmatter
echo "# No frontmatter here" > "$TMPDIR/no-fm.md"
assert_output_contains "missing frontmatter" "$TMPDIR/no-fm.md" "WARN: missing YAML frontmatter"

# Test 2: Valid spec with all required sections passes
cat > "$TMPDIR/valid.md" << 'HEREDOC'
---
type: spec
phase: SPEC
status: draft
---
# Valid Spec

## Overview
This is a valid spec.

## Problem Statement
The problem is defined.

## User Personas

### Persona: Developer
- **Role:** Software developer

## Functional Requirements

### Must Have
- **REQ-001:** Basic functionality
HEREDOC
assert_no_output "valid doc passes" "$TMPDIR/valid.md"

# Test 3: TBD marker detected
cat > "$TMPDIR/tbd.md" << 'HEREDOC'
---
type: spec
phase: SPEC
status: draft
---
# Spec with TBD

## Overview
This will be TBD later.
HEREDOC
assert_output_contains "TBD detected" "$TMPDIR/tbd.md" "WARN: placeholder found"

# Test 4: TODO marker detected
cat > "$TMPDIR/todo.md" << 'HEREDOC'
---
type: plan
phase: PLAN
status: draft
---
# Plan

## Overview
TODO: fill this in.
HEREDOC
assert_output_contains "TODO detected" "$TMPDIR/todo.md" "WARN: placeholder found"

# Test 5: Template placeholder detected
cat > "$TMPDIR/template.md" << 'HEREDOC'
---
type: spec
phase: SPEC
status: draft
---
# {{PROJECT_NAME}} Spec

## Overview
This uses a template placeholder.
HEREDOC
assert_output_contains "template placeholder" "$TMPDIR/template.md" "WARN: placeholder found"

# Test 6: Broken relative link
cat > "$TMPDIR/broken-link.md" << 'HEREDOC'
---
type: spec
phase: SPEC
status: draft
---
# Spec

## Overview
See [the plan](../plans/nonexistent-plan.md) for details.
HEREDOC
assert_output_contains "broken link" "$TMPDIR/broken-link.md" "WARN: broken link"

# Test 7: Non-existent file exits silently
output=$(bash scripts/verify-doc.sh "/nonexistent/path.md" 2>&1 || true)
if [ -z "$output" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: non-existent file should exit silently"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
