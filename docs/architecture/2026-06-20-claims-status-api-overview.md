---
spec: 2026-06-20-claims-status-api
kernel_modules: []
external_dependencies:
  - name: Azure Container Registry (ACR)
    justification: Stores the built container image; AKS pulls from it via managed identity (ADR-003), no static credential.
  - name: Azure Kubernetes Service (AKS)
    justification: Hosting platform for the Deployment/Service (REQ-305/306); required by the spec's deployment target.
  - name: GitHub Actions / Azure AD OIDC federation
    justification: CI/CD identity for provisioning and deployment (REQ-308), with no long-lived cloud credential stored in CI.
components: [api, container, infra, k8s, cicd]
---

# Claims Status API — Architecture Overview

No requirement in this spec is tagged `[verifiable]`/`[verifiable-model]`
(per the spec's Verification Identification section and ADR-002's
consequences), so `kernel_modules` is empty — `art-kernel-boundary`'s
req_map requirement is vacuously satisfied. There is no formally
verified kernel for this service; correctness is established by tests
only (`art-test-first`).

## Components

- **api** — ASP.NET Core Minimal API (`ClaimsApi`) mapping
  `GET /claims/{claimId}`, `GET /claims`, `GET /health` to handlers
  backed by `IClaimsRepository` (ADR-002).
- **container** — multi-stage Dockerfile (REQ-303): SDK image builds and
  publishes, ASP.NET runtime image runs as a non-root user on port 8080.
- **infra** — Bicep templates (REQ-304) provisioning ACR (admin
  disabled) and AKS (system-assigned managed identity, RBAC enabled),
  with `AcrPull` granted to the cluster identity (ADR-003).
- **k8s** — `Deployment` (REQ-305: liveness/readiness probes on
  `/health`, CPU/memory requests+limits, dedicated `claims-api`
  namespace) and `Service` of type `LoadBalancer` (REQ-306, ADR-004).
- **cicd** — GitHub Actions workflow: build/test/dependency-scan
  unconditionally (REQ-307), push/provision/deploy gated on OIDC secrets
  (REQ-308, ADR-003).

```mermaid
flowchart LR
  subgraph cicd [GitHub Actions]
    Build[build/test/scan]
    Deploy[push/provision/deploy\n(OIDC-gated)]
    Build --> Deploy
  end
  subgraph azure [Azure]
    ACR[(ACR)]
    AKS[AKS Cluster]
    subgraph aks_ns [namespace: claims-api]
      Pod[ClaimsApi Pod]
      Svc[Service: LoadBalancer]
    end
  end
  Deploy -->|push image, managed identity AcrPull| ACR
  Deploy -->|apply Bicep + manifests, OIDC| AKS
  ACR -->|AcrPull, managed identity| Pod
  AKS --> Pod
  Pod --> Svc
  Caller([API caller]) -->|public IP, port 80| Svc
  Svc -->|port 8080| Pod
```

## Data flow

- A caller sends `GET /claims/{claimId}`, `GET /claims`, or `GET /health`
  to the `Service`'s public IP (port 80), forwarded to the `Pod`
  (port 8080).
- The handler reads from `IClaimsRepository`'s in-memory seeded store —
  no external data source, no network call, no disk I/O during request
  handling.
- Response is a JSON body (claim shape or array) or an RFC 9457
  problem-details body (400/404), or the health payload.
- Separately, GitHub Actions builds the image, pushes it to ACR via
  OIDC-authenticated `az`/`docker` calls, and applies the Bicep
  templates and Kubernetes manifests to AKS — this is a deploy-time data
  flow, disjoint from the request-time flow above.

## Verified kernel boundary
None — this spec waives `[verifiable]`/`[verifiable-model]` tagging
entirely (see Verification Identification in the design spec). All
correctness is established by xUnit tests (unit + `WebApplicationFactory`
integration) per the Success Metrics.
