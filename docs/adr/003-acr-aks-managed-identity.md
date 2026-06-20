---
id: ADR-003
status: accepted
date: 2026-06-20
addresses: [REQ-304, REQ-307, REQ-308]
---

# ADR-003: ACR + AKS provisioned via Bicep, no static registry/cloud credentials

## Context
REQ-304 provisions ACR + AKS; REQ-307/308 build/push/deploy from GitHub
Actions. The platform/DevOps persona's success criterion is "no manual
`kubectl`/`az` steps" with no static cloud credentials in CI
(`art-secrets-hygiene`).

## Decision
- ACR is provisioned with admin access **disabled**.
- AKS is provisioned with a **system-assigned managed identity**, RBAC
  enabled, and that identity is granted the `AcrPull` role on the ACR
  instance — this is how nodes pull images, with no registry secret
  ever stored anywhere.
- GitHub Actions authenticates to Azure exclusively via **OIDC federated
  identity** (`azure/login` with `AZURE_CLIENT_ID`/`AZURE_TENANT_ID`/
  `AZURE_SUBSCRIPTION_ID` secrets, no client secret or service-principal
  password). The push/provision/deploy steps (REQ-308) run only when
  these secrets are present; they are skipped, not failed, otherwise.
- The build/test/scan steps (REQ-307) run unconditionally and require no
  Azure access at all — they are not gated behind the OIDC secrets.

## Consequences
- No static credential of any kind (registry password, service
  principal secret) exists in this system — the only secret material is
  the OIDC trust relationship itself, which is short-lived and scoped.
- A repo without Azure access configured still gets full build/test/scan
  coverage on every PR; only the deploy tail is inert.
- Crosses a trust boundary at the OIDC token exchange (GitHub Actions ⟷
  Azure AD) — carried into the threat model
  (`docs/architecture/2026-06-20-claims-status-api-threat-model.md`) as
  `dfe-4`.

## Alternatives Considered
- **ACR admin credentials + Kubernetes `imagePullSecret`**: rejected —
  reintroduces a static, rotatable secret that managed identity makes
  unnecessary.
- **Service-principal client-secret auth for GitHub Actions**: rejected
  in favor of OIDC — a client secret is a long-lived static credential
  that OIDC federation specifically eliminates.
