#!/usr/bin/env bash
# Configure GitHub branch protection for the SpecFlow v2 workflow.
# Requires: gh CLI authenticated with admin scope.
set -euo pipefail

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [ -z "$REPO" ]; then
  echo "ERROR: Not in a GitHub repository or gh CLI not authenticated."
  echo ""
  echo "Manual setup instructions:"
  echo "  Go to Settings → Branches → Add rule for 'main':"
  echo "    - Require pull request reviews (1 approval)"
  echo "    - Require status checks to pass (ci, verifier)"
  echo "    - Restrict direct pushes to repo admins only"
  exit 1
fi

echo "Configuring branch protection for $REPO..."

gh api repos/"$REPO"/branches/main/protection \
  --method PUT \
  --input - << 'EOF' || {
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["ci", "verifier"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null
}
EOF
  echo ""
  echo "ERROR: Failed to set branch protection. You may lack admin permissions."
  echo ""
  echo "Manual setup instructions:"
  echo "  Go to Settings → Branches → Add rule for 'main':"
  echo "    - Require pull request reviews (1 approval)"
  echo "    - Require status checks to pass (ci, verifier)"
  echo "    - Restrict direct pushes to repo admins only"
  exit 1
}

echo "Branch protection configured for main:"
echo "  - Require 1 PR review approval"
echo "  - Require CI + verifier status checks"
echo "  - Admins can bypass for minor doc fixes"
