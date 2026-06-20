#!/usr/bin/env bash
# Clean up stale git worktrees and merged task branches.
set -euo pipefail

echo "Pruning stale worktrees..."
git worktree prune -v

echo ""
echo "Finding merged task branches (impl/*/task-*)..."
MERGED=0
for branch in $(git branch --merged main --list 'impl/*/task-*' 2>/dev/null); do
  branch=$(echo "$branch" | tr -d ' *')
  echo "  Deleting merged branch: $branch"
  git branch -d "$branch" 2>/dev/null || true
  MERGED=$((MERGED + 1))
done

if [ "$MERGED" -eq 0 ]; then
  echo "  No merged task branches to clean up."
else
  echo "  Cleaned up $MERGED merged task branches."
fi
