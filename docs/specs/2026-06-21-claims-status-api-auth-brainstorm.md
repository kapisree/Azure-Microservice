---
type: brainstorm
phase: BRAINSTORM
spec: 2026-06-21-claims-status-api-auth
status: accepted
created: "2026-06-21"
---

# Brainstorm — Claims Status API Authentication

## Goal
Add authentication to the Claims Status API (`docs/specs/2026-06-20-claims-status-api-design.md`), closing the unauthenticated-access gap accepted for v1 under ADR-004 / SEC-001, while staying within this feature's own minimal scope (no TLS, no rate limiting, no full identity provider).

## Constraints
- Auth mechanism: shared-secret API key (`X-Api-Key` header) — explicitly not JWT or Azure AD/OIDC, to keep scope minimal.
- Scope: protects `GET /claims` and `GET /claims/{claimId}` only. `GET /health` stays open — AKS kubelet liveness/readiness probes can't send custom headers.
- Key storage: a Kubernetes Secret, injected into the Deployment as an env var. No Azure Key Vault — out of scope (more infra than this feature warrants).
- Rotation: single key only, no multi-key/zero-downtime rotation — accept the brief gap.
- Rejection: missing and wrong key both return a generic `401`, no distinction in the body (no oracle for an attacker) — but with a `WWW-Authenticate` header for legitimate-integrator debuggability.
- Provisioning: a new GitHub Actions repo secret feeds the existing OIDC-gated deploy job, which creates/updates the k8s Secret.
- Local dev/tests: `appsettings.Development.json` gets a placeholder key; xUnit tests override via `WebApplicationFactory` config, not a real secret.

## Alternatives considered

**Auth mechanism:**
- JWT bearer token (validated, no IdP) — rejected: needs a token issuer decision this feature doesn't want to make.
- Azure AD / Entra ID (OIDC) — rejected for now: heavier setup (app registration, tenant config); revisit if a real identity boundary is ever needed.
- **API key (chosen):** simplest mechanism that closes SEC-001's "unauthenticated read access" gap without a new identity system.

**Implementation mechanism (ASP.NET Core):**
- B — custom `AuthenticationHandler<T>` + `[Authorize]` — rejected: idiomatic but more ceremony (schemes, `ClaimsPrincipal`) than "compare one header to one string" needs.
- C — plain `app.Use(...)` middleware with a path check — rejected: path-string matching is more fragile than route-group scoping.
- **A — `IEndpointFilter` on a `/claims` route group (chosen):** matches the existing minimal-API style in `Program.cs`, scopes cleanly without touching `/health`, independently unit-testable.

**Key storage:**
- Azure Key Vault synced into AKS — rejected: stronger secret management, but adds a new Azure resource + CSI driver setup, more infra scope than this feature needs.
- **Kubernetes Secret (chosen):** consistent with the existing no-static-credentials posture (REQ-304/ADR-003), no new infra resource.

## Fresh-eyes review (pre-spec)
Three personas reviewed this design before it was written up: security-architect, azure-cloud-architect/platform-DevOps-owner, and service-consumer/backend-engineer. All three verdicts: **proceed with named changes**, none required rework. Findings folded into the spec:

- **Security:** API-key-over-plain-HTTP is authentication, not confidentiality, and is not a TLS substitute — must be stated explicitly, tied to ADR-004's `tb-1` boundary. Comparison must use `CryptographicOperations.FixedTimeEquals`, not `string.Equals`. The CI secret-passing mechanism must avoid putting the key value in a process's argv (`--from-literal="$VAR"` is visible via `/proc/<pid>/cmdline`) — use a file-based secret instead.
- **Platform/DevOps:** four concrete bugs in the original CI sketch: (1) Secret must be applied before the Deployment, or pods hit `CreateContainerConfigError`; (2) updating a k8s Secret doesn't restart pods — rotation needs an explicit `kubectl rollout restart`; (3) the `kubectl create secret` command needs an explicit `-n claims-api`, or it lands in the wrong namespace; (4) if the `CLAIMS_API_KEY` repo secret is never set, the workflow currently would succeed anyway with an empty key value — needs an explicit fail-fast guard. Also flagged: this narrows ADR-004's `tb-1` boundary and should be an ADR amendment in ARCHITECTURE, not a silent change.
- **Service-consumer/DX:** 401 must reuse the exact same `Results.Problem(statusCode:, detail:)` shape as the existing 400/404s, not a bespoke body. Add `WWW-Authenticate: ApiKey realm="claims-api"` for debuggability while keeping the body collapsed. `/health`'s exemption must be stated explicitly (probe constraint), not left implicit. Auth check must precede route/GUID validation — i.e. a malformed `claimId` with no key still returns 401, not 400.

## Decision
Add an `ApiKeyFilter : IEndpointFilter` applied to `app.MapGroup("/claims")`, validated via `CryptographicOperations.FixedTimeEquals` against `IOptions<ApiKeySettings>`. `/health` is unaffected. Production key lives in a Kubernetes Secret (namespace-scoped, applied before the Deployment, with an explicit `kubectl rollout restart` step on rotation), provisioned by a new `CLAIMS_API_KEY` GitHub Actions secret with a fail-fast guard if unset. 401 responses reuse the existing `Results.Problem` shape plus a `WWW-Authenticate` header. This is `[verifiable-model]`-tagged per `art-formal-verification`'s authentication-logic trigger.

## Hand-off
SPECIFY phase turns this into `docs/specs/2026-06-21-claims-status-api-auth-design.md`, extending `docs/specs/2026-06-20-claims-status-api-design.md`, with REQ-309 through REQ-314 covering the auth filter, exemption, error shape, key storage, CI provisioning, and local-dev/test config. ARCHITECTURE phase must amend ADR-004 to reflect the narrowed `tb-1` boundary.
