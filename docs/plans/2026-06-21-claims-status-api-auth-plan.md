---
type: plan
phase: PLAN
spec: 2026-06-21-claims-status-api-auth
decisions: [ADR-004, ADR-005]
created: "2026-06-21"
---

# Claims Status API Authentication — Implementation Plan

Implements REQ-309, REQ-310, REQ-311 (per ADR-005); REQ-312, REQ-313,
REQ-313(e), REQ-314 (per ADR-004's amendment + ADR-005's external-
dependency framing).

This plan consumes ARCHITECTURE-phase decisions (ADR-004's amendment,
ADR-005) as given — it does not re-derive the kernel-module split or
the `IEndpointFilter`-on-route-group mechanism. It describes intent and
ordering only.

**The runnable test code, the `ApiKeyFilter`/`Authorize` implementation,
and the Dafny proof body live in the IMPLEMENT phase, never in this
PLAN document** — same rule the base plan and demo plan follow.
Signatures, contracts, and `ensures`-clause intent are stated in prose
so an implementer has the contract to build against without the
answer being transcribable.

REQ-312/313/313(e) describe infrastructure artifacts (k8s manifests, CI
workflow) with no unit-testable behavior of their own — same rationale
as the base plan's Tasks P6-P8: "done" is manifest/workflow review
against the Success Metrics, not a test an implementer could copy.

REQ-309 is `[verifiable-model]` — Task A4 below is the proof task;
`art-formal-verification` applies only to it.

## Files

**Modified:**
- `src/ClaimsApi/Program.cs` — route registration refactored into
  `app.MapGroup("/claims")` so `ApiKeyFilter` can be scoped to exactly
  the two data-returning endpoints; `claimId` stays `string`-bound and
  manually parsed (unchanged, per ADR-005's binding constraint).
- `src/ClaimsApi/appsettings.json` — adds an empty `ApiKey:Value`
  section (so `IConfiguration` binding has a key to bind to in every
  environment; production overrides via `ApiKey__Value` env var).
- `src/ClaimsApi/appsettings.Development.json` — adds a placeholder,
  non-production `ApiKey:Value` (REQ-314).
- `infra/k8s/deployment.yaml` — adds `ApiKey__Value` env var sourced
  via `secretKeyRef` from the `claims-api-key` Secret (REQ-312).
- `.github/workflows/claims-api.yml` — extends the `provision-and-deploy`
  job per REQ-313(a)-(d) and REQ-313(e).

**Created:**
- `src/ClaimsApi/ApiKeyFilter.cs` — the `Authorize` predicate (kernel
  module, per ADR-005) plus the non-kernel `IEndpointFilter` shell.
- `infra/k8s/secret.yaml` — placeholder `Secret` manifest with an empty
  `stringData` value (the real value is injected by CI at deploy time
  per REQ-313(b)/(c); this file documents shape/name/namespace for
  `kubectl apply -f infra/k8s/`'s static manifests, distinct from the
  CI-generated Secret apply — see Task A6's note on why both exist).
- `tests/ClaimsApi.Tests/ApiKeyFilterTests.cs` — REQ-309/310/311 tests.
- `verification/claims_api_auth/api_key_filter.dfy` — Dafny model proof
  of REQ-309's `Authorize` predicate and precedence invariant.

## Task A1: Refactor route registration into `MapGroup("/claims")`

No new behavior, no new failing test required — this is a pure
restructuring step under the existing green test suite, same as any
refactor `art-test-first` doesn't gate (the existing
`ClaimsEndpointsTests.cs`/`HealthEndpointTests.cs` are the safety net
that must stay green throughout).

- [ ] **Step 1:** In `Program.cs`, replace the two top-level
  `app.MapGet("/claims", ...)` / `app.MapGet("/claims/{claimId}", ...)`
  calls with `var claims = app.MapGroup("/claims");` followed by
  `claims.MapGet("", ...)` and `claims.MapGet("/{claimId}", ...)`,
  preserving handler bodies exactly. `app.MapGet("/health", ...)`
  stays a top-level `app.Map*` call, outside the group (REQ-310's
  exemption depends on this).
- [ ] **Step 2:** Run `dotnet test`. Confirm every existing test still
  passes (route shape is unchanged from the client's perspective).
- [ ] **Step 3:** Commit:
  ```
  git add src/ClaimsApi/Program.cs
  git commit -m "refactor(claims-api): route /claims endpoints through MapGroup"
  ```

## Task A2: `Authorize` predicate + `ApiKeyFilter` (REQ-309, REQ-310, REQ-311)

**Signature the kernel module must expose** (per ADR-005, this is the
entire kernel boundary for this feature):
```
static bool Authorize(string? presented, string configured)
```
Postcondition: returns `true` if and only if `presented` is non-null
and exactly equals `configured`. The caller (the filter shell, not this
function) is responsible for sourcing `configured` from
`IConfiguration` and comparing via
`CryptographicOperations.FixedTimeEquals` rather than calling this
predicate with `==` directly in production — `Authorize` itself models
the *logical* relation the proof verifies; the filter shell is where
the timing-safe comparison actually happens (REQ-309's Verification
scope note: Dafny doesn't model `FixedTimeEquals`'s timing behavior).

**Tests to write first** in `tests/ClaimsApi.Tests/ApiKeyFilterTests.cs`,
using `WebApplicationFactory` with a configuration override supplying a
known test key (REQ-314):
1. `GET /claims` and `GET /claims/{validSeedId}` with the correct
   `X-Api-Key` header → unchanged base-spec behavior (`200 OK`, same
   body shape as Task P4/P5's existing tests).
2. `GET /claims` with no `X-Api-Key` header → `401`, body via
   `Results.Problem(401, detail: "Missing or invalid API key.")`
   (REQ-311), response has `WWW-Authenticate: ApiKey realm="claims-api"`.
3. `GET /claims` with a wrong `X-Api-Key` value → same `401` response
   as test 2 — assert the body is byte-for-byte identical to test 2's
   body (the "never distinguish missing from wrong" guarantee).
4. `GET /claims/not-a-guid` with **no** `X-Api-Key` header → `401`,
   **not** `400` (REQ-309's precedence invariant — this is the test
   that would fail if `claimId` were ever retyped to `Guid`).
5. `GET /health` with no `X-Api-Key` header → unchanged `200 OK`
   (REQ-310 — confirms `ApiKeyFilter` does not apply outside the
   `/claims` group).

- [ ] **Step 1:** Write the five tests above.
- [ ] **Step 2:** Run `dotnet test`. Confirm tests 2-4 fail (no filter
  exists yet, so today everything 200s/400s without auth) and test 1/5
  pass trivially (no change yet) — record which fail before
  implementing, per `art-test-first`.
- [ ] **Step 3:** Implement `ApiKeyFilter.cs`: the `Authorize` static
  method per the signature above; an `IEndpointFilter` class whose
  `InvokeAsync` reads `X-Api-Key` from `context.HttpContext.Request.Headers`,
  reads the configured key from `IConfiguration["ApiKey:Value"]`
  (bound via `ApiKeySettings` options, REQ-309's precondition), calls
  `CryptographicOperations.FixedTimeEquals` on the UTF-8 bytes of
  presented vs. configured (treating a missing header as automatic
  failure without calling `FixedTimeEquals` on a null), and on failure
  returns the REQ-311 problem-details result with the `WWW-Authenticate`
  header set before calling `next`; on success calls `await next(context)`
  unchanged.
- [ ] **Step 4:** In `Program.cs`, register the filter on the route
  group from Task A1: `claims.AddEndpointFilter<ApiKeyFilter>();` (or
  the equivalent factory-based `AddEndpointFilter` overload — either
  satisfies REQ-309's "scoped to `/claims`" requirement).
- [ ] **Step 5:** Add the `ApiKey` configuration section: bind
  `IConfiguration.GetSection("ApiKey")` to an `ApiKeySettings` class
  with a `Value` property; register it in DI.
- [ ] **Step 6:** Add the placeholder `ApiKey:Value` entries to
  `appsettings.json` (empty) and `appsettings.Development.json`
  (non-production placeholder, REQ-314).
- [ ] **Step 7:** Run `dotnet test`. Confirm all five new tests pass
  and every pre-existing test (`HealthEndpointTests`,
  `ClaimsEndpointsTests`, `InMemoryClaimsRepositoryTests`) still passes
  unchanged.
- [ ] **Step 8:** Commit:
  ```
  git add src/ClaimsApi/Program.cs src/ClaimsApi/ApiKeyFilter.cs src/ClaimsApi/appsettings.json src/ClaimsApi/appsettings.Development.json tests/ClaimsApi.Tests/ApiKeyFilterTests.cs
  git commit -m "feat(claims-api): API key auth on /claims route group (REQ-309, REQ-310, REQ-311, REQ-314)"
  ```

## Task A3: xUnit test-config override for `ApiKey:Value` (REQ-314, folded into A2)

Already covered by Task A2's tests using `WebApplicationFactory`'s
`ConfigureAppConfiguration`/`WithWebHostBuilder` to inject a known test
key independent of `appsettings.Development.json`'s placeholder — no
separate task; called out here only so REQ-314's second sentence has an
explicit pointer to where it's satisfied.

## Task A4: Dafny proof (REQ-309)

In `verification/claims_api_auth/api_key_filter.dfy`, write a method
(e.g. `HandleRequest`) parameterized by `presented: string`,
`configured: string`, and a boolean `claimIdIsValidGuid` standing in for
the route-validation outcome (the proof does not need to model GUID
grammar itself — only that *some* boolean routing-validation fact
exists and that auth precedes it), returning a `datatype Response =
Unauthorized | BadRequest | Authorized`. Required `ensures` clauses:
- `presented != configured ==> r == Unauthorized` — holds regardless of
  `claimIdIsValidGuid`'s value; this is the precedence invariant. Model
  `Authorize(presented, configured)` as its own named predicate
  (`presented == configured`) so the proof and the C# signature in
  Task A2 share the same relation name in spirit.
- `presented == configured && !claimIdIsValidGuid ==> r == BadRequest`
- `presented == configured && claimIdIsValidGuid ==> r == Authorized`

Header comment: `// Proves: REQ-309`. Run `dafny verify
verification/claims_api_auth/api_key_filter.dfy`, confirm 0 errors.

This is a `[verifiable-model]` proof — it verifies the model (the
predicate and the ordering), not `ApiKeyFilter.cs` directly; Task A2's
five tests cover the real implementation, including
`FixedTimeEquals`'s call site, which the proof explicitly excludes
(REQ-309's Verification scope note).

- [ ] **Step 1:** Write the `.dfy` file per the contract above.
- [ ] **Step 2:** Run `dafny verify`, confirm 0 errors.
- [ ] **Step 3:** Commit:
  ```
  git add verification/claims_api_auth/api_key_filter.dfy
  git commit -m "verify(claims-api): Dafny model proof for Authorize precedence (REQ-309)"
  ```

## Task A5: Kubernetes Secret + Deployment wiring (REQ-312)

- [ ] **Step 1:** Create `infra/k8s/secret.yaml`:
  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: claims-api-key
    namespace: claims-api
  type: Opaque
  stringData:
    ApiKey__Value: "placeholder-overwritten-by-ci"
  ```
  This static file exists for `kubectl apply -f infra/k8s/` to have a
  shape to validate (`kubectl apply --dry-run=client`, same
  credential-free check pattern as the base plan's Bicep/manifest
  tasks); REQ-313(b)'s CI-generated Secret (from the real
  `CLAIMS_API_KEY` value) overwrites this placeholder at deploy time
  via `kubectl apply` on the same resource name/namespace — REQ-313(c)
  requires the CI-generated apply to happen *before*
  `kubectl apply -f infra/k8s/`, so by the time this static file's
  apply runs, the real Secret already exists and this placeholder
  apply is a no-op `stringData` overwrite back to the placeholder.
  **This ordering matters**: if `infra/k8s/secret.yaml`'s apply ever
  ran *after* the CI-generated real-value apply without itself being
  excluded or made consistent, it would clobber the real key with the
  placeholder. Task A6 must apply `infra/k8s/` selectively (excluding
  `secret.yaml`, or applying it first and then immediately
  re-applying the CI-generated real value last) — see Task A6, Step 3.
- [ ] **Step 2:** In `infra/k8s/deployment.yaml`, add to the container
  spec:
  ```yaml
          env:
            - name: ApiKey__Value
              valueFrom:
                secretKeyRef:
                  name: claims-api-key
                  key: ApiKey__Value
  ```
- [ ] **Step 3:** Validate with
  `kubectl apply --dry-run=client -f infra/k8s/` (credential-free,
  same as the base plan's manifest validation). Confirm no schema
  errors.
- [ ] **Step 4:** Commit:
  ```
  git add infra/k8s/secret.yaml infra/k8s/deployment.yaml
  git commit -m "feat(claims-api): k8s Secret + Deployment env var wiring (REQ-312)"
  ```

## Task A6: CI workflow extension (REQ-313(a)-(e))

Modifies `.github/workflows/claims-api.yml`'s `provision-and-deploy`
job, inserted between the existing "Deploy to AKS" steps
(`az aks get-credentials` and the final `kubectl apply -f infra/k8s/`):

- [ ] **Step 1 (REQ-313(a), fail-fast guard):** Add a step immediately
  after `az aks get-credentials`:
  ```yaml
      - name: Check CLAIMS_API_KEY secret is set
        env:
          CLAIMS_API_KEY: ${{ secrets.CLAIMS_API_KEY }}
        run: |
          if [ -z "$CLAIMS_API_KEY" ]; then
            echo "::error::CLAIMS_API_KEY repo secret is unset or empty; aborting deploy."
            exit 1
          fi
  ```
- [ ] **Step 2 (REQ-313(e), namespace before Secret):** Add, before the
  Secret-create step:
  ```yaml
      - name: Apply namespace
        run: kubectl apply -f infra/k8s/namespace.yaml
  ```
- [ ] **Step 3 (REQ-313(b)/(c), file-based Secret apply, ordering vs.
  Task A5's static manifest):** Add:
  ```yaml
      - name: Create/update API key Secret
        env:
          CLAIMS_API_KEY: ${{ secrets.CLAIMS_API_KEY }}
        run: |
          tmpfile=$(mktemp)
          printf '%s' "$CLAIMS_API_KEY" > "$tmpfile"
          kubectl create secret generic claims-api-key \
            --from-file=ApiKey__Value="$tmpfile" \
            -n claims-api --dry-run=client -o yaml | kubectl apply -f -
          rm -f "$tmpfile"
  ```
  Then change the existing final manifest-apply line to exclude the
  static placeholder Secret, so it can never clobber the real value
  just applied: `kubectl apply -f infra/k8s/ --prune=false` alone is
  insufficient (it would still apply `secret.yaml`'s placeholder over
  the real value) — instead apply namespace/deployment/service
  explicitly: `kubectl apply -f infra/k8s/namespace.yaml -f infra/k8s/deployment.yaml -f infra/k8s/service.yaml`
  (the namespace re-apply here is idempotent and harmless; the explicit
  file list is what excludes `secret.yaml` from this step).
- [ ] **Step 4 (REQ-313(d), rollout restart):** Add, after the
  Deployment apply step:
  ```yaml
      - name: Restart rollout to pick up current key
        run: kubectl rollout restart deployment/claims-api -n claims-api
  ```
- [ ] **Step 5:** Lint the workflow YAML locally (e.g.
  `python -c "import yaml; yaml.safe_load(open('.github/workflows/claims-api.yml'))"`
  — credential-free, same pattern as the base plan's CI validation).
  This cannot be exercised end-to-end without live OIDC credentials
  (same constraint as the base spec and this spec's Open Question #2);
  code review of the guard/ordering stands in, as before.
- [ ] **Step 6:** Commit:
  ```
  git add .github/workflows/claims-api.yml
  git commit -m "feat(claims-api): fail-fast guard, namespace-first Secret provisioning, rollout restart (REQ-313, REQ-313(e))"
  ```

## Task A7: Update plan's source-of-truth cross-references

- [ ] **Step 1:** Confirm `bash scripts/check-traceability.sh` and
  `bash scripts/analyze-adr-plan-linkage.sh` both pass with this plan's
  frontmatter (`decisions: [ADR-004, ADR-005]`, both of which `address`
  REQ-309).
- [ ] **Step 2:** Run `bash scripts/run-quality-gates.sh` end to end;
  confirm `All quality gates passed` with the dotnet test count
  increased by 5 (Task A2) and the Dafny verified-file count increased
  by 1 (Task A4).
