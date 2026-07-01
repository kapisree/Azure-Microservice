#!/usr/bin/env bash
# Governance test: deploy workflow must use least-privilege OIDC credentials.
# Guards against AZURE_CREDENTIALS (broad JSON auth with Contributor on the
# entire resource group) being used in the Container Apps deploy workflow.
# OIDC login with scoped roles (AcrPush + ContainerApp Contributor) is required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
pass() { echo "ok:   $1"; }

DEPLOY_WF=".github/workflows/deploy-containerapp.yml"

# 1. Workflow must exist.
if [[ -f "$DEPLOY_WF" ]]; then
  pass "$DEPLOY_WF exists"
else
  fail "$DEPLOY_WF missing — Container Apps deploy workflow not found"
  echo "test_workflow_security: FAILED"; exit 1
fi

# 2. Must NOT use broad AZURE_CREDENTIALS (JSON auth).
#    JSON auth embeds a long-lived client secret with Contributor on the full
#    resource group — far broader than needed to push an image and update one app.
if grep -q 'AZURE_CREDENTIALS' "$DEPLOY_WF"; then
  fail "$DEPLOY_WF uses secrets.AZURE_CREDENTIALS (broad JSON auth) — use OIDC instead"
else
  pass "$DEPLOY_WF does not use broad AZURE_CREDENTIALS"
fi

# 3. Must declare id-token: write permission (required for OIDC token exchange).
if grep -q 'id-token: write' "$DEPLOY_WF"; then
  pass "$DEPLOY_WF declares id-token: write"
else
  fail "$DEPLOY_WF missing 'id-token: write' — OIDC login requires this permission"
fi

# 4. Must use OIDC login (client-id + tenant-id + subscription-id), not creds:.
if grep -q 'client-id:' "$DEPLOY_WF" && grep -q 'tenant-id:' "$DEPLOY_WF" && grep -q 'subscription-id:' "$DEPLOY_WF"; then
  pass "$DEPLOY_WF uses OIDC login (client-id / tenant-id / subscription-id)"
else
  fail "$DEPLOY_WF does not use OIDC login — replace 'creds: AZURE_CREDENTIALS' with client-id/tenant-id/subscription-id"
fi

# 5. Must declare an explicit permissions block (no implicit write-all default).
if grep -q '^permissions:' "$DEPLOY_WF"; then
  pass "$DEPLOY_WF has top-level permissions block"
else
  fail "$DEPLOY_WF missing top-level 'permissions:' block — implicit default grants write-all"
fi

# 6. Must NOT grant write access to contents (deploy job needs read only).
if grep -qE '^\s*contents:\s*write' "$DEPLOY_WF"; then
  fail "$DEPLOY_WF grants 'contents: write' — deploy job needs read only"
else
  pass "$DEPLOY_WF does not grant contents: write"
fi

if [[ $FAIL -ne 0 ]]; then
  echo "test_workflow_security: FAILED"
  exit 1
fi
echo "test_workflow_security: all checks passed"
