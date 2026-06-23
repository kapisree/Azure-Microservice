#!/usr/bin/env bash
# Run the SpecFlow verifier via headless Claude (claude -p) on your
# Claude Code subscription — no API key needed.
#
# IMPORTANT: run this in a SEPARATE terminal, outside any Claude Code
# session. A Claude session cannot spawn another Claude session.
#
# Usage:
#   scripts/run-verifier.sh                 # review current branch vs main, print findings
#   scripts/run-verifier.sh <PR-number>     # same, and post findings to the PR
#   scripts/run-verifier.sh <PR-number> --persona   # persona mode instead of full mode
#   scripts/run-verifier.sh --no-post <PR>  # PR context but print only
#
# Implements the option-3 verifier process (review-gate.md step 3).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "${CLAUDECODE:-}" == "1" ]]; then
  echo "ERROR: you are inside a Claude Code session (CLAUDECODE=1)." >&2
  echo "A Claude session cannot spawn another Claude session." >&2
  echo "Open a separate terminal and run this script there." >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: 'claude' CLI not found. Install Claude Code and log in first." >&2
  exit 1
fi

MODE="full"
PR=""
POST=1
for arg in "$@"; do
  case "$arg" in
    --persona) MODE="persona" ;;
    --no-post) POST=0 ;;
    [0-9]*)    PR="$arg" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

BASE_BRANCH="${BASE_BRANCH:-main}"
MODEL="${VERIFIER_MODEL:-opus}"

git fetch origin "$BASE_BRANCH" --quiet || true

HEAD_SHA="$(git rev-parse --short HEAD)"
CHANGED="$(git diff --name-only "origin/${BASE_BRANCH}...HEAD" -- '*.md' | grep -v '^specflow-scaffold/' || true)"

if [[ -z "$CHANGED" ]]; then
  echo "No markdown documents changed vs origin/${BASE_BRANCH} — nothing to verify."
  # Retro 2026-06-22-sec-006-process-gap, proposal #3 (option a, narrowly
  # scoped): impl/sec-* back-edge branches and patch/* branches were
  # already reviewed once (the SECURITY finding, or the patch-tier human
  # review) before this branch existed, and their PR diffs are small by
  # construction. For those branch shapes only, post a clearly-labeled
  # "not applicable" attestation so the CI check doesn't stay permanently
  # red for a PR shape the verifier was never going to have anything to
  # review on. This does NOT substitute for human review (review-gate.md
  # step 5 still applies) and does NOT extend to plain impl/* IMPLEMENT
  # branches, where the markdown-only scope gap remains open (see the
  # retro's Open Question #1).
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [[ -n "$PR" && "$POST" -eq 1 && "$CURRENT_BRANCH" =~ ^(impl/sec-|patch/) ]]; then
    if command -v gh >/dev/null 2>&1; then
      NOTE="$(mktemp)"
      trap 'rm -f "$NOTE"' EXIT
      {
        echo "<!-- specflow-verifier:none-applicable sha:${HEAD_SHA} -->"
        echo "## SpecFlow verifier — not applicable — \`${HEAD_SHA}\`"
        echo
        echo "No markdown documents changed on \`${CURRENT_BRANCH}\` vs origin/${BASE_BRANCH} — nothing for the verifier to review (it reviews \`*.md\` diffs only). This branch shape (\`impl/sec-*\` back-edge or \`patch/*\`) was already reviewed once before this branch existed. Human review (\`.claude/rules/review-gate.md\` step 5) is still required before merge — this comment only satisfies the mechanical CI attestation, it does not assert the code/test/proof diff was reviewed."
      } > "$NOTE"
      gh pr comment "$PR" --body-file "$NOTE"
      echo "Posted a not-applicable attestation to PR #$PR (branch matches impl/sec-*|patch/*, no markdown changed)."
      BRANCH="$(gh pr view "$PR" --json headRefName --jq .headRefName)"
      RUN_ID="$(gh run list --workflow Verifier --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
      if [[ -n "$RUN_ID" ]]; then
        gh run rerun "$RUN_ID" --failed 2>/dev/null \
          && echo "Re-ran Verifier workflow (run $RUN_ID) to refresh the attestation check." \
          || true
      fi
    else
      echo "WARNING: gh CLI not found — not-applicable attestation not posted to PR #$PR." >&2
    fi
  fi
  exit 0
fi

echo "Verifier mode: $MODE | model: $MODEL | base: origin/${BASE_BRANCH} | head: ${HEAD_SHA}"
echo "Changed documents:"
echo "$CHANGED" | sed 's/^/  - /'
echo

PROMPT="You are the SpecFlow verifier running in ${MODE} mode.

First read .claude/skills/verifier/SKILL.md and constitution.md, then follow the skill's '${MODE}' mode instructions exactly (citation discipline included: blocking findings prefixed with the violated [art-slug]).

Review these documents, changed on this branch relative to ${BASE_BRANCH}:
$(echo "$CHANGED" | sed 's/^/- /')

Read each changed document in full. Also check cross-document consistency with the unchanged repo (constitution.md, CLAUDE.md, .claude/rules/review-gate.md, related specs/plans/ADRs).

Output ONLY the structured findings list in GitHub-flavored markdown (no preamble, no code fences around the whole output). If there are zero findings, output exactly: 'No findings. Documents reviewed: <list>'. End with a one-line verdict: APPROVE or REQUEST_CHANGES (REQUEST_CHANGES iff any critical or high finding)."

OUT="$(mktemp)"
FINDINGS="$(mktemp)"
trap 'rm -f "$OUT" "$FINDINGS"' EXIT

echo "Running verifier via claude -p — this can take several minutes." >&2
echo "(claude -p prints nothing until the review is complete; do not interrupt.)" >&2
echo >&2

# Capture stderr into the stream so a claude failure is visible, not silent.
set +e
claude -p "$PROMPT" --model "$MODEL" --allowedTools "Read,Grep,Glob" 2>&1 | tee "$FINDINGS"
CLAUDE_EXIT=${PIPESTATUS[0]}
set -e

if [[ "$CLAUDE_EXIT" -ne 0 ]]; then
  echo >&2
  echo "ERROR: claude -p exited with code $CLAUDE_EXIT (output above). Nothing posted." >&2
  exit "$CLAUDE_EXIT"
fi
if [[ ! -s "$FINDINGS" ]]; then
  echo "ERROR: claude -p produced no output. Nothing posted." >&2
  echo "Check 'claude --version' and that you are logged in ('claude' then /status)." >&2
  exit 1
fi

{
  echo "<!-- specflow-verifier:${MODE} sha:${HEAD_SHA} -->"
  echo "## SpecFlow verifier (${MODE} mode) — \`${HEAD_SHA}\`"
  echo
  echo "_Run locally via \`scripts/run-verifier.sh\` (claude -p, subscription auth)._"
  echo
  cat "$FINDINGS"
} > "$OUT"

if [[ -n "$PR" && "$POST" -eq 1 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "WARNING: gh CLI not found — findings printed above but not posted to PR #$PR." >&2
    exit 1
  fi
  gh pr comment "$PR" --body-file "$OUT"
  echo
  echo "Findings posted to PR #$PR."
  # Re-run the Verifier workflow so the attestation check turns green.
  BRANCH="$(gh pr view "$PR" --json headRefName --jq .headRefName)"
  RUN_ID="$(gh run list --workflow Verifier --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
  if [[ -n "$RUN_ID" ]]; then
    gh run rerun "$RUN_ID" --failed 2>/dev/null \
      && echo "Re-ran Verifier workflow (run $RUN_ID) to refresh the attestation check." \
      || echo "Note: could not re-run workflow $RUN_ID automatically — re-run the failed 'Verifier findings posted' check from the PR page."
  fi
fi
