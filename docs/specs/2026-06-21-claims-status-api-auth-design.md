---
type: spec
phase: SPEC
status: draft
created: "2026-06-21"
approved_by: ""
supersedes: ""
extends: "2026-06-20-claims-status-api-design"
superseded_by: ""
extended_by: ""
---

# Claims Status API Authentication Specification

## Overview

Adds shared-secret API key authentication to the Claims Status API (`docs/specs/2026-06-20-claims-status-api-design.md`), protecting the two data-returning endpoints (`GET /claims`, `GET /claims/{claimId}`) while leaving the health-check endpoint open. This closes the unauthenticated-access gap accepted for v1 under `docs/adr/004-public-loadbalancer-exposure.md` and tracked as SEC-001 in `docs/security/0.1.0-disposition.md` (expiry 2026-12-31) — but it closes only the *authentication* gap, not the underlying transport gap: the service still runs over plain HTTP, no TLS. This spec is explicit that an API key over an unencrypted channel is authentication, not confidentiality, and must not be read as having fully resolved the `tb-1` trust boundary ADR-004 named.

### Scope
In: Service consumer — must present a valid API key to read claim data; gets a clear, consistent 401 on missing/invalid key. In: Platform/DevOps owner — gets the key provisioned and rotated through the existing OIDC-gated CI/CD pipeline, with no manual `kubectl` step for a routine deploy. Out: any caller-identity model beyond "possesses the shared key" — there is no per-caller key, scope, or audit trail in this version; that is a future spec's concern if ever needed. Out: TLS termination, rate limiting, multi-key rotation — all remain out of scope per the base spec's Won't Have, carried forward here.

## Problem Statement

The base spec's v1 explicitly deferred authentication (`Won't Have`), and ADR-004 accepted the resulting public, unauthenticated exposure as a named trust boundary (`tb-1`) conditioned on the data being synthetic only — "this acceptance is conditional and revocable." This spec is that revisit: it adds the cheapest authentication control that meaningfully restricts who can call `GET /claims`/`GET /claims/{claimId}`, without expanding scope into TLS, rate limiting, or a full identity provider (any of which would be a larger, separate spec).

## User Personas

### Persona: Service Consumer
- **Role:** An internal client or front-end calling the API.
- **Goal:** Look up a claim's current status programmatically, now with a required credential.
- **Context:** Calls over HTTP/JSON; must send `X-Api-Key: <key>` on every call to `GET /claims` or `GET /claims/{claimId}`; `GET /health` needs no key. The key is provisioned to them out-of-band (not by this API).
- **Success looks like:** Calls with a valid key behave exactly as in the base spec (same 200/400/404 bodies). Calls with a missing or wrong key get a `401` with enough information (`WWW-Authenticate` header) to recognize "this is an auth problem," without the response body revealing whether the key was absent or simply wrong.

### Persona: Platform/DevOps Owner
- **Role:** Owns the AKS cluster and CI/CD pipeline (unchanged from the base spec).
- **Goal:** Ship the auth feature, and later rotate the key, with no manual `kubectl`/`az` steps beyond what the existing pipeline already requires.
- **Context:** Adds one new GitHub Actions repo secret (`CLAIMS_API_KEY`); the existing OIDC-gated deploy job must create/update the Kubernetes Secret *before* applying the Deployment, and must fail loudly (not silently succeed with an empty key) if the repo secret was never configured.
- **Success looks like:** A merge to `main` provisions the key into the cluster, in the right namespace, before any pod that needs it starts; rotating the key (changing the repo secret + re-running the deploy) actually takes effect, because the rollout is explicitly restarted.

## Objectives

1. Require a valid API key on every call to `GET /claims` and `GET /claims/{claimId}`; leave `GET /health` open.
2. Reject invalid/missing keys with a `401` that is indistinguishable (in body) between "missing" and "wrong," but carries a `WWW-Authenticate` header for legitimate debugging.
3. Store the key as a Kubernetes Secret, provisioned by the existing OIDC-gated CI/CD pipeline from a new GitHub Actions repo secret, with correct ordering, namespacing, and a fail-fast guard against an unset secret.
4. Make rotation actually work (pods pick up a changed key) without expanding to multi-key/zero-downtime rotation.
5. State explicitly, in the spec text, that this feature provides authentication only — it does not add confidentiality (no TLS) and does not fully close ADR-004's `tb-1` boundary.

## Functional Requirements

### Must Have

- **REQ-309:** [verifiable-model] API key validation on `GET /claims` and `GET /claims/{claimId}`.
  - **Precondition:** A configured key value (`ApiKeySettings.Value`) exists, sourced from configuration (env var in production, `appsettings.Development.json` locally, test-supplied override in xUnit).
  - **Postcondition:** The request is authorized if and only if the presented `X-Api-Key` header value exactly equals the configured key, compared via `System.Security.Cryptography.CryptographicOperations.FixedTimeEquals` (not `string.Equals`/`==`, to avoid a timing side-channel). Authorized requests proceed to the existing endpoint logic unchanged (REQ-300/REQ-301 of the base spec). Unauthorized requests short-circuit before that logic ever runs and never touch `IClaimsRepository`.
  - **Invariant:** The authorization check happens before any route-level validation (e.g. GUID parsing for `claimId`) — a request with an invalid `claimId` *and* a missing/wrong key always returns `401`, never `400`. This precedence holds only if `claimId` stays bound as `string` and is parsed manually inside the handler (per the base plan's Task P4, Step 3); retyping the route parameter to `Guid claimId` or adding a `:guid` route constraint would let ASP.NET Core's model binder reject malformed input with a `400` before `ApiKeyFilter` ever runs, breaking this invariant and diverging the implementation from REQ-309's proof. IMPLEMENT must keep `claimId` string-bound for this reason, not merely as a style choice.
  - **Verification scope:** The Dafny proof models the match predicate (`Authorize(presented, configured) == (presented == configured)`) and the precedence invariant (auth-before-routing) as a contract model — it does not model `FixedTimeEquals`'s timing behavior, which is a non-functional property outside Dafny's scope. Tests exercise the real `ApiKeyFilter` against the actual ASP.NET Core pipeline, including the precedence case (bad GUID + bad key → 401, not 400).
- **REQ-310:** `GET /health` requires no API key and is unaffected by `ApiKeyFilter` — verified by it sitting outside the `/claims` route group it's scoped to. TDD only (no verification tag — this is routing structure, not an authentication contract).
- **REQ-311:** A `401` response from `ApiKeyFilter` uses `Results.Problem(statusCode: 401, detail: "Missing or invalid API key.")` — the same `Results.Problem` mechanism the base spec's 400/404 responses already use, not a bespoke body shape — and additionally sets a `WWW-Authenticate: ApiKey realm="claims-api"` response header. The body never distinguishes "missing" from "wrong."
- **REQ-312:** The production API key is stored as a Kubernetes Secret (`claims-api-key`, namespace `claims-api`) and injected into the `Deployment`'s container as the environment variable `ApiKey__Value` via `secretKeyRef`. The Secret manifest is applied before the Deployment manifest in the deploy sequence.
- **REQ-313:** The GitHub Actions workflow's existing OIDC-gated deploy job is extended to: (a) fail the job explicitly if the `CLAIMS_API_KEY` repo secret is empty or unset, before attempting anything else; (b) write the secret value to a temporary file (not a command-line argument) and create/update the Kubernetes Secret from that file (e.g. `kubectl create secret generic claims-api-key --from-file=ApiKey__Value=<tmpfile> -n claims-api --dry-run=client -o yaml | kubectl apply -f -`), avoiding exposure of the key value via process argv; (c) apply the Secret before `kubectl apply -f infra/k8s/`; (d) on every deploy run (not only when the key value changed), run `kubectl rollout restart deployment/claims-api -n claims-api` after applying the Deployment, so a rotated key actually takes effect on existing pods.
- **REQ-314:** `appsettings.Development.json` carries a placeholder, non-production `ApiKey:Value` for local `dotnet run`. The xUnit test suite (`tests/ClaimsApi.Tests/`) configures its own key value via `WebApplicationFactory`'s configuration override, independent of any real secret.

> REQ-309 is the only requirement in this spec tagged `[verifiable-model]` — it is the one piece of authentication logic this feature adds, per `art-formal-verification`'s tagging guidance. REQ-310/311/312/313/314 are infrastructure, response-shape, and configuration concerns covered by tests/manifest review, not Dafny.

### Should Have
(none — the surface above is the complete scope of this feature)

### Won't Have (this version)
- JWT bearer tokens, Azure AD/Entra ID, or any other identity-provider-based auth — API key only.
- Multi-key support or zero-downtime key rotation — single key, rotation accepts a brief gap while pods restart.
- TLS/HTTPS termination — carried forward unchanged from the base spec's Won't Have; this feature explicitly does not address it, and the key is sent in the clear.
- Rate limiting or per-caller quotas — carried forward unchanged from the base spec.
- Per-caller identity, scoped keys, or an audit trail of who used the key — there is exactly one shared secret, not a caller-identity model.
- Protecting `GET /health` — it must remain reachable without a key for AKS liveness/readiness probes (REQ-305 of the base spec), which cannot send custom headers.

## Non-Functional Requirements
- **Performance:** No change from the base spec — the auth check is a single fixed-time byte comparison, not a meaningful latency contributor.
- **Security:** This feature provides **authentication, not confidentiality.** The key travels in plaintext over the same unencrypted `LoadBalancer:80` path as the rest of the traffic (per ADR-004's `tb-1`). A network-position attacker who can observe traffic can capture the key and retain full access until the next manual rotation — this is a materially different (and in one sense worse) risk than the base spec's "no auth" gap, which had no durable credential to steal. This spec does not claim to close `tb-1`; ARCHITECTURE phase must amend ADR-004 to reflect that the boundary is narrowed (read access now requires a credential) but not eliminated (no transport security yet). Single-key rotation has no overlap window — treat a rotation as a planned brief-availability-gap event, not zero-downtime.
- **Scalability:** Out of scope — unchanged from the base spec.
- **Compliance:** Unchanged from the base spec — no real claimant data, synthetic/seeded only.

## Verification Identification

Per `art-formal-verification`, REQ-309 is tagged `[verifiable-model]`: a Dafny proof models the authorization predicate and the auth-before-routing precedence invariant; tests cover the real `ApiKeyFilter` implementation, including the `FixedTimeEquals` call and the precedence case. No other requirement in this spec meets the tagging trigger (REQ-310 is routing structure, REQ-311 is response shape, REQ-312–314 are infrastructure/config).

## Success Metrics
1. REQ-309's Dafny proof verifies, and a named acceptance test exists for each of its contract clauses: valid key → 200 (unchanged base-spec behavior), missing key → 401, wrong key → 401, invalid GUID + missing key → 401 (not 400).
2. REQ-310 has a passing test confirming `GET /health` succeeds with no `X-Api-Key` header at all.
3. REQ-311 has a passing test confirming the 401 body matches the existing `Results.Problem` shape and the response carries `WWW-Authenticate: ApiKey realm="claims-api"`.
4. REQ-313's CI changes are exercised by a workflow run: a deploy with `CLAIMS_API_KEY` unset fails the job explicitly (verified by code review of the guard, since this session has no live Azure subscription to run it against — same constraint as the base spec's Open Question #1); a deploy with the secret set succeeds and the Secret/Deployment ordering is correct per manifest review.

## Open Questions
1. ARCHITECTURE phase must amend ADR-004 (not write a new ADR) to record that this feature narrows `tb-1` — read access now requires a credential — without closing it, since transport security is unchanged. This spec does not itself amend the ADR; it flags the obligation forward. ARCHITECTURE must also map REQ-309 to a kernel-boundary module per `art-kernel-boundary`, since this is the first `[verifiable-model]` requirement this product introduces — the base spec had no verifiable REQs, so there is no existing kernel-boundary precedent to follow.
2. This session has no live Azure subscription (same constraint as the base spec) — REQ-312/313's k8s Secret ordering, namespacing, and rollout-restart behavior can be code-reviewed and manifest-validated but not exercised against a live cluster until credentials exist out-of-band.
3. Should the single-key rotation gap (REQ-313(d)'s forced restart) be tracked as a new accepted finding in a future SECURITY disposition (mirroring the SEC-002 "accepted, low" pattern), or is it sufficiently covered by this spec's explicit Non-Functional Requirements caveat? Deferred to the SECURITY phase for this feature's eventual release — this deferral is not a pre-disposition of the outcome; per `art-threat-driven-security` and ADR-004's own "provisional, not a settled disposition" caveat, the SECURITY phase's second reviewer remains free to score this risk critical/high and trigger the back-edge rather than accept it.
4. This feature partially closes the gap SEC-001 covers (`docs/security/0.1.0-disposition.md`, currently `status: accepted`, expiry 2026-12-31). When this feature reaches its own SECURITY/RELEASE phase, SEC-001's disposition entry must be reconciled (e.g. superseded or annotated) rather than left to expire untouched, since the accepted finding no longer accurately describes a fully-open gap.

## Assumptions
- A human with repository admin access will provision the `CLAIMS_API_KEY` GitHub Actions secret out-of-band before the first deploy that includes this feature — this spec only consumes that secret, consistent with how the base spec treats the Azure OIDC secrets.
- Callers of `GET /claims`/`GET /claims/{claimId}` receive their API key value through some out-of-band channel (e.g. a secrets manager, a deployment runbook) — this spec does not define key distribution to callers, only validation.
- The `claims-api` Kubernetes namespace already exists (per the base spec's REQ-305) before this feature's Secret is applied.

## Risks
- **Risk:** An API key sent over plaintext HTTP can be captured by anyone positioned to observe the traffic, granting durable access until manual rotation. **Severity:** Medium (level with SEC-001's existing disposition in `docs/security/0.1.0-disposition.md`, not an escalation above it — SEC-001 is already recorded as Medium/accepted, and ADR-004's Context notes the fresh-eyes review rated the underlying exposure High; this risk introduces a stealable credential where none existed before, which is why it stays at the same severity rather than dropping). **Mitigation:** This spec states the limitation explicitly rather than letting the feature read as "the exposure is now fixed"; ARCHITECTURE phase must amend ADR-004 accordingly; TLS remains a prerequisite for any future reuse of this pattern with real data, exactly as the base spec already states.
- **Risk:** First-ever deploy after this feature merges could silently create an empty-value Secret if `CLAIMS_API_KEY` was never configured, leaving every request rejected while CI reports green. **Severity:** Medium. **Mitigation:** REQ-313(a)'s explicit fail-fast guard turns this into a loud CI failure instead of a silent runtime outage.
- **Risk:** Updating the Kubernetes Secret alone does not restart existing pods, so a "rotated" key would silently not take effect without an explicit restart trigger. **Severity:** Low (caught in this spec's design review before implementation). **Mitigation:** REQ-313(d)'s explicit `kubectl rollout restart` on every deploy.
