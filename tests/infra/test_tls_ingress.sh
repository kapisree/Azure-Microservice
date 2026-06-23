#!/usr/bin/env bash
# Covers: SEC-007 (impl/sec-sec-007 back-edge) — the API-key channel must
# not be reachable over plaintext HTTP via a public LoadBalancer. Asserts
# the Service is internal-only (ClusterIP) and TLS is terminated at an
# Ingress backed by a cert-manager-issued certificate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
pass() { echo "ok:   $1"; }

SERVICE=infra/k8s/service.yaml
INGRESS=infra/k8s/ingress.yaml
ISSUER=infra/k8s/cluster-issuer.yaml
HOST="claims-api.aicodeingdemo.com"

# 1. The Service must no longer be a public LoadBalancer — TLS now
#    terminates at the Ingress, and the Service should only be reachable
#    from inside the cluster.
if [[ -f "$SERVICE" ]]; then
  if grep -qE '^\s*type:\s*LoadBalancer' "$SERVICE"; then
    fail "$SERVICE is still type: LoadBalancer (public, plaintext) — SEC-007"
  else
    pass "$SERVICE is not a public LoadBalancer"
  fi
else
  fail "$SERVICE missing"
fi

# 2. An Ingress resource must exist, be TLS-only, and reference the host.
if [[ -f "$INGRESS" ]]; then
  if ! grep -qE '^\s*kind:\s*Ingress' "$INGRESS"; then
    fail "$INGRESS does not declare kind: Ingress"
  else
    pass "$INGRESS declares kind: Ingress"
  fi
  if ! grep -q "$HOST" "$INGRESS"; then
    fail "$INGRESS does not reference host $HOST"
  else
    pass "$INGRESS references host $HOST"
  fi
  if ! grep -qE '^\s*tls:' "$INGRESS"; then
    fail "$INGRESS has no tls: section"
  else
    pass "$INGRESS has a tls: section"
  fi
  if ! grep -qE 'cert-manager\.io/cluster-issuer' "$INGRESS"; then
    fail "$INGRESS missing cert-manager.io/cluster-issuer annotation"
  else
    pass "$INGRESS has a cert-manager.io/cluster-issuer annotation"
  fi
else
  fail "$INGRESS missing"
fi

# 3. A cert-manager ClusterIssuer must exist, targeting Let's Encrypt prod
#    via an HTTP-01 solver (no extra DNS-provider credentials required).
if [[ -f "$ISSUER" ]]; then
  if ! grep -qE '^\s*kind:\s*ClusterIssuer' "$ISSUER"; then
    fail "$ISSUER does not declare kind: ClusterIssuer"
  else
    pass "$ISSUER declares kind: ClusterIssuer"
  fi
  if ! grep -q 'acme-v02.api.letsencrypt.org/directory' "$ISSUER"; then
    fail "$ISSUER does not target the Let's Encrypt production ACME server"
  else
    pass "$ISSUER targets the Let's Encrypt production ACME server"
  fi
  if ! grep -qE '^\s*-?\s*http01:' "$ISSUER"; then
    fail "$ISSUER has no http01 solver"
  else
    pass "$ISSUER has an http01 solver"
  fi
else
  fail "$ISSUER missing"
fi

if [[ $FAIL -eq 0 ]]; then
  echo "test_tls_ingress: all checks passed"
  exit 0
fi
exit 1
