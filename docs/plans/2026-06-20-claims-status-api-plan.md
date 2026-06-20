---
type: plan
phase: PLAN
spec: 2026-06-20-claims-status-api
decisions: [ADR-002, ADR-003, ADR-004]
created: "2026-06-20"
---

# Claims Status API — Implementation Plan

Implements REQ-300, REQ-301, REQ-302 (per ADR-002); REQ-303; REQ-304,
REQ-307, REQ-308 (per ADR-003); REQ-305, REQ-306 (per ADR-004).

This plan consumes the ARCHITECTURE-phase decisions (ADR-002/003/004) as
given — it does not re-derive the Minimal API shape, the managed-identity
model, or the LoadBalancer-exposure acceptance. It describes intent and
ordering only.

**The runnable test code and implementation code for REQ-300/301/302
live in the IMPLEMENT phase, never in this PLAN document** — same rule
the demo plan follows (`docs/plans/2026-05-28-demo-greeting-plan.md`).
Embedding the test assertions and the handler bodies here would let an
implementer transcribe the answer instead of practicing TDD, which
violates `art-test-first` in substance even if the ceremony (write test,
watch it fail, then implement) is still followed. Below, each API task
states *what the test must verify* and *what the implementation must do*
in prose plus exact signatures/contracts — never the test or
implementation body itself.

REQ-303–308 describe infrastructure artifacts (container, Bicep, k8s
manifests, CI workflow) that have no unit-testable behavior of their
own — there is no failing test to write first for a Dockerfile. For
those, this plan does show the actual file content, because the
"answer to skip" concern doesn't apply: "done" is the static,
credential-free validation named in the spec's Success Metrics
(`docker build`, `az bicep build`, `kubectl --dry-run=client`, workflow
YAML lint), not a test an implementer could instead just copy.

No requirement in this spec is `[verifiable]`/`[verifiable-model]`
(spec's Verification Identification section, ADR-002's consequences) —
no Dafny proof task exists in this plan; `art-formal-verification`
doesn't apply here.

## Files

**Created:**
- `ClaimsApi.sln` — solution referencing both projects below; needed so
  `dotnet build`/`dotnet format`/`dotnet test` (invoked with no project
  argument by `scripts/quality-gates-other.sh`) resolve unambiguously
  from the repo root.
- `src/ClaimsApi/ClaimsApi.csproj` — `Microsoft.NET.Sdk.Web`, `net8.0`
  (current LTS; this dev environment's installed SDK is 10.0.301, which
  builds older TFMs as long as the matching targeting pack is present —
  verified in Task P1, Step 0, rather than assumed).
- `src/ClaimsApi/Program.cs` — Minimal API host; top-level statements
  plus a trailing `public partial class Program { }` so
  `WebApplicationFactory<Program>` in the test project can see it
  (the standard ASP.NET Core minimal-hosting test pattern — this is
  test-harness plumbing, not REQ behavior, so it's scaffolded directly
  in Task P1 rather than TDD'd).
- `src/ClaimsApi/ClaimStatus.cs` — enum: `Submitted`, `UnderReview`,
  `Approved`, `Denied`, `Paid`.
- `src/ClaimsApi/Claim.cs` — `record Claim(Guid ClaimId, ClaimStatus Status, DateTimeOffset LastUpdated)`.
- `src/ClaimsApi/IClaimsRepository.cs` — the ADR-002 domain seam:
  `Claim? GetById(Guid claimId)`, `IReadOnlyList<Claim> GetAll()`.
- `src/ClaimsApi/InMemoryClaimsRepository.cs` — `IClaimsRepository`
  implementation seeding a fixed in-memory list at construction, using
  fixed literal `Guid` values (not `Guid.NewGuid()`) so tests can
  reference known ids deterministically instead of discovering them at
  runtime through another endpoint.
- `src/ClaimsApi/Dockerfile` — multi-stage build (REQ-303).
- `tests/ClaimsApi.Tests/ClaimsApi.Tests.csproj` — `net8.0`, xUnit +
  `Microsoft.AspNetCore.Mvc.Testing`.
- `tests/ClaimsApi.Tests/HealthEndpointTests.cs` — REQ-302.
- `tests/ClaimsApi.Tests/InMemoryClaimsRepositoryTests.cs` — unit tests
  backing REQ-300/301's data layer.
- `tests/ClaimsApi.Tests/ClaimsEndpointsTests.cs` — REQ-300 (400/404/200)
  + REQ-301 (list) integration tests via `WebApplicationFactory`.
- `infra/bicep/main.bicep` — REQ-304, per ADR-003 (admin-disabled ACR,
  managed-identity AKS, `AcrPull` role assignment).
- `infra/k8s/namespace.yaml`, `infra/k8s/deployment.yaml`,
  `infra/k8s/service.yaml` — REQ-305/306, per ADR-004 (`LoadBalancer`
  accepted as `tb-1`).
- `.github/workflows/claims-api.yml` — REQ-307 (unconditional
  build/test/scan job) + REQ-308 (OIDC-gated push/provision/deploy job),
  per ADR-003. Kept separate from the existing `.github/workflows/ci.yml`
  (factory's own quality-gates check) and `verifier.yml` — this workflow
  is product CI/CD, not factory governance. **The deploy job's `if:`
  additionally requires `github.ref == 'refs/heads/main'` — this is a
  plan-level addition, not something ADR-003 itself specifies.** ADR-003
  only names "OIDC secrets present" as the gating condition; restricting
  to the `main` branch on top of that is this plan's call, to avoid a
  same-repo PR run (which does have access to repo secrets, unlike a
  fork PR) triggering a real Azure deploy. If a reviewer considers this
  significant enough to be architectural, it should become an ADR-003
  amendment rather than silently shipping as an implementation detail —
  flagging it here so it's visible instead.

## Task P1: Solution and project scaffolding

No REQ behavior is implemented in this task — it only creates enough of
a compilable, runnable host for later tasks to write failing tests
against. `dotnet new` scaffolds; this is setup, not implementation, so
`art-test-first` does not require a preceding failing test for it.

0. **Verify the toolchain before relying on it**, rather than assuming:
   `dotnet --list-sdks` and `dotnet --list-runtimes`. Confirm an SDK
   capable of building `net8.0` is present (an SDK majorversion newer
   than 8 — e.g. 10.x, confirmed installed in this environment — can
   still target `net8.0` as long as the `Microsoft.NETCore.App` 8.x
   runtime pack resolves; if `dotnet build` in Step 4 below fails with
   a missing-targeting-pack error instead of a normal compile error,
   that's the cause). `docker`, `az`, and `kubectl` are confirmed **not
   installed** in this dev environment as of this plan's writing —
   Tasks P6/P7/P8 already account for this; don't be surprised by it.
1. From the repo root:
   ```
   dotnet new sln -n ClaimsApi
   dotnet new web -n ClaimsApi -o src/ClaimsApi
   dotnet new xunit -n ClaimsApi.Tests -o tests/ClaimsApi.Tests
   dotnet sln add src/ClaimsApi/ClaimsApi.csproj tests/ClaimsApi.Tests/ClaimsApi.Tests.csproj
   dotnet add tests/ClaimsApi.Tests/ClaimsApi.Tests.csproj reference src/ClaimsApi/ClaimsApi.csproj
   dotnet add tests/ClaimsApi.Tests/ClaimsApi.Tests.csproj package Microsoft.AspNetCore.Mvc.Testing
   ```
2. Replace the generated `src/ClaimsApi/Program.cs` body with:
   ```csharp
   var builder = WebApplication.CreateBuilder(args);
   var app = builder.Build();
   app.Run();

   public partial class Program { }
   ```
   This is the minimum host needed to compile and run with zero routes
   — it contains no REQ behavior, only the `WebApplicationFactory<Program>`
   test-visibility hook.
3. Confirm `src/ClaimsApi/` contains only `ClaimsApi.csproj` and
   `Program.cs` (the `web` template shouldn't generate extra
   `WeatherForecast`-style scaffolding, but check).
4. Run `dotnet build` from the repo root. Expected: build succeeds.
5. Commit:
   ```
   git add ClaimsApi.sln src/ClaimsApi tests/ClaimsApi.Tests
   git commit -m "chore(claims-api): scaffold solution, Web + xUnit/WebApplicationFactory projects"
   ```

## Task P2: `GET /health` (REQ-302)

**Test to write first:** Using `WebApplicationFactory<Program>`, issue
`GET /health` against the test client. Assert the response status is
`200 OK` and the JSON body's `status` field equals `"healthy"`
(REQ-302's literal example body, `{ "status": "healthy" }`).

- [ ] **Step 1:** Write that test in
  `tests/ClaimsApi.Tests/HealthEndpointTests.cs`.
- [ ] **Step 2:** Run `dotnet test`. Confirm it **fails** — no
  `/health` route is mapped yet, so the request 404s.
- [ ] **Step 3:** Implement the minimal route in `Program.cs` (between
  `builder.Build()` and `app.Run()`): map `GET /health` to a handler
  that unconditionally returns `200 OK` with a body whose `status`
  property is `"healthy"` — no dependency on `IClaimsRepository` (the
  overview's component description is explicit about this:
  `docs/architecture/2026-06-20-claims-status-api-overview.md`).
- [ ] **Step 4:** Run `dotnet test`, confirm it passes.
- [ ] **Step 5:** Commit:
  ```
  git add src/ClaimsApi/Program.cs tests/ClaimsApi.Tests/HealthEndpointTests.cs
  git commit -m "feat(claims-api): GET /health (REQ-302)"
  ```

## Task P3: Domain model + `IClaimsRepository` seam (per ADR-002)

**Produces (signatures later tasks depend on):**
- `enum ClaimStatus { Submitted, UnderReview, Approved, Denied, Paid }`
- `record Claim(Guid ClaimId, ClaimStatus Status, DateTimeOffset LastUpdated)`
- `interface IClaimsRepository { Claim? GetById(Guid claimId); IReadOnlyList<Claim> GetAll(); }`
- `class InMemoryClaimsRepository : IClaimsRepository` — seeds exactly
  five claims at construction, one per `ClaimStatus` value, keyed by
  these fixed literal ids (use exactly these GUIDs, not generated
  ones, so Tasks P4/P5's tests can reference a known id without first
  calling `GET /claims`):
  - `3fa85f64-5717-4562-b3fc-2c963f66afa6` → `Submitted`
  - `7c9e6679-7425-40de-944b-e07fc1f90ae7` → `UnderReview`
  - `f47ac10b-58cc-4372-a567-0e02b2c3d479` → `Approved`
  - `9b2e815c-5a91-4d5c-8b16-13b8b1b3c3a1` → `Denied`
  - `d290f1ee-6c54-4b01-90e6-d701748f0851` → `Paid`

**Tests to write first** in
`tests/ClaimsApi.Tests/InMemoryClaimsRepositoryTests.cs`:
1. `GetAll()` returns all five seeded claims.
2. `GetById()` with one of the five fixed ids above (e.g.
   `3fa85f64-5717-4562-b3fc-2c963f66afa6`) returns the claim with that
   id and the expected `ClaimStatus`.
3. `GetById()` with a freshly generated `Guid.NewGuid()` (guaranteed
   not to collide with the five fixed seed ids) returns `null`.

- [ ] **Step 1:** Write the three tests above.
- [ ] **Step 2:** Run `dotnet test`, confirm it fails (the types don't
  exist yet — a compile error counts as "failing" here).
- [ ] **Step 3:** Implement `ClaimStatus.cs`, `Claim.cs`,
  `IClaimsRepository.cs`, `InMemoryClaimsRepository.cs` per the
  signatures and fixed seed ids above.
- [ ] **Step 4:** Run `dotnet test`, confirm all three pass.
- [ ] **Step 5:** Commit:
  ```
  git add src/ClaimsApi/ClaimStatus.cs src/ClaimsApi/Claim.cs src/ClaimsApi/IClaimsRepository.cs src/ClaimsApi/InMemoryClaimsRepository.cs tests/ClaimsApi.Tests/InMemoryClaimsRepositoryTests.cs
  git commit -m "feat(claims-api): domain model + IClaimsRepository seam (ADR-002)"
  ```

## Task P4: `GET /claims/{claimId}` (REQ-300)

**Interfaces consumed:** `IClaimsRepository.GetById(Guid)` and the five
fixed seed ids from Task P3 — this task no longer depends on Task P5's
`GET /claims` to discover a valid id, since the seed ids are now fixed
literals known at plan-writing time.

**Tests to write first** in
`tests/ClaimsApi.Tests/ClaimsEndpointsTests.cs`:
1. `GET /claims/not-a-guid` → `400 Bad Request`, RFC 9457
   problem-details body, `detail` states the id is not a valid GUID.
2. `GET /claims/{a freshly generated Guid.NewGuid()}` → `404 Not Found`,
   problem-details body, `detail` states no claim was found.
3. `GET /claims/3fa85f64-5717-4562-b3fc-2c963f66afa6` (one of Task P3's
   fixed seed ids) → `200 OK`, body `{ claimId, status, lastUpdated }`
   with `status` equal to the string `"Submitted"`.

- [ ] **Step 1:** Write the three tests above.
- [ ] **Step 2:** Run `dotnet test`, confirm all three fail (no
  `/claims/{claimId}` route yet).
- [ ] **Step 3:** Implement the route in `Program.cs`: register
  `IClaimsRepository` in DI (`AddSingleton<IClaimsRepository, InMemoryClaimsRepository>()`),
  then map `GET /claims/{claimId}` to a handler that: parses the route
  parameter as a `Guid` (400 + problem-details on parse failure, per
  test 1); looks it up via `IClaimsRepository.GetById` (404 +
  problem-details if `null`, per test 2); otherwise returns `200 OK`
  with `{ claimId, status, lastUpdated }` where `status` is the enum
  value's string name (per test 3 and REQ-300's exact body shape).
- [ ] **Step 4:** Run `dotnet test`, confirm all three pass.
- [ ] **Step 5:** Commit:
  ```
  git add src/ClaimsApi/Program.cs tests/ClaimsApi.Tests/ClaimsEndpointsTests.cs
  git commit -m "feat(claims-api): GET /claims/{claimId} (REQ-300)"
  ```

## Task P5: `GET /claims` (REQ-301)

**Interfaces consumed:** `IClaimsRepository.GetAll()` from Task P3.

**Test to write first:** `GET /claims` → `200 OK`, JSON array of all
five seeded claims, same per-element shape as Task P4's single-claim
body (`{ claimId, status, lastUpdated }`).

- [ ] **Step 1:** Write that test in
  `tests/ClaimsApi.Tests/ClaimsEndpointsTests.cs`.
- [ ] **Step 2:** Run `dotnet test`, confirm it fails (no `/claims`
  route yet).
- [ ] **Step 3:** Implement `GET /claims` in `Program.cs`: map to a
  handler that returns `200 OK` with the full `IClaimsRepository.GetAll()`
  result, projected to the same `{ claimId, status, lastUpdated }` shape
  used in Task P4.
- [ ] **Step 4:** Run `dotnet test`, confirm every test in the project
  passes.
- [ ] **Step 5:** Commit:
  ```
  git add src/ClaimsApi/Program.cs tests/ClaimsApi.Tests/ClaimsEndpointsTests.cs
  git commit -m "feat(claims-api): GET /claims (REQ-301)"
  ```

## Task P6: Multi-stage Dockerfile (REQ-303)

No xUnit test applies to a Dockerfile; "done" is the spec's own Success
Metric #2 (`docker build` succeeds, container serves `/health` as 200
locally). `docker` is confirmed not installed in this dev environment
(Task P1, Step 0) — write the file regardless; validation against a
real Docker daemon is deferred to wherever that's available, same
category as the spec's existing Open Questions about live Azure access.

1. Write `src/ClaimsApi/Dockerfile`:
   ```dockerfile
   FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
   WORKDIR /src
   COPY ClaimsApi.sln .
   COPY src/ClaimsApi/ClaimsApi.csproj src/ClaimsApi/
   COPY tests/ClaimsApi.Tests/ClaimsApi.Tests.csproj tests/ClaimsApi.Tests/
   RUN dotnet restore ClaimsApi.sln
   COPY src/ClaimsApi/ src/ClaimsApi/
   RUN dotnet publish src/ClaimsApi/ClaimsApi.csproj -c Release -o /app

   FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
   WORKDIR /app
   RUN adduser --disabled-password --gecos "" appuser
   COPY --from=build /app .
   USER appuser
   EXPOSE 8080
   ENV ASPNETCORE_URLS=http://+:8080
   ENTRYPOINT ["dotnet", "ClaimsApi.dll"]
   ```
2. Where Docker is available: `docker build -f src/ClaimsApi/Dockerfile -t claims-api:local .`
   Expected: image builds successfully.
3. `docker run --rm -p 8080:8080 claims-api:local` then, in another
   terminal, `curl -i http://localhost:8080/health`. Expected: `200 OK`
   with `{"status":"healthy"}`.
4. Commit:
   ```
   git add src/ClaimsApi/Dockerfile
   git commit -m "feat(claims-api): multi-stage non-root Dockerfile (REQ-303)"
   ```

## Task P7: Bicep templates — ACR + AKS (REQ-304, per ADR-003)

No xUnit test applies; "done" is `az bicep build` succeeding (the
credential-free static check the spec's Risk mitigation names — full
`az deployment group create` validation against a live subscription is
explicitly deferred per the spec's Open Question #1). `az` is confirmed
not installed in this dev environment (Task P1, Step 0) — write the
template regardless.

1. Write `infra/bicep/main.bicep` parameterized (location, names) with:
   - An `Microsoft.ContainerRegistry/registries` resource,
     `properties.adminUserEnabled: false`.
   - An `Microsoft.ContainerService/managedClusters` resource with
     `identity.type: 'SystemAssigned'` and `properties.enableRBAC: true`.
   - A `Microsoft.Authorization/roleAssignments` resource granting the
     AKS cluster's principal the `AcrPull` role
     (`7f951dda-4ed3-4680-a7ca-43fe172d538d`) scoped to the ACR
     resource — this is the mechanism ADR-003 names for credential-free
     image pulls.
2. Where the `az` CLI is available: `az bicep build --file infra/bicep/main.bicep`.
   Expected: compiles to ARM JSON with no errors.
3. Commit:
   ```
   git add infra/bicep/main.bicep
   git commit -m "feat(claims-api): Bicep ACR + AKS, managed identity AcrPull (REQ-304, ADR-003)"
   ```

## Task P8: Kubernetes manifests — Deployment + Service (REQ-305/306, per ADR-004)

No xUnit test applies; "done" is `kubectl apply --dry-run=client -f
infra/k8s/` succeeding (static manifest validation, no live cluster
required). `kubectl` is confirmed not installed in this dev environment
(Task P1, Step 0) — write the manifests regardless.

1. Write `infra/k8s/namespace.yaml`:
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: claims-api
   ```
2. Write `infra/k8s/deployment.yaml` with: `namespace: claims-api`,
   `livenessProbe`/`readinessProbe` both `httpGet: { path: /health, port: 8080 }`,
   and `resources.requests`/`resources.limits` set on `cpu`/`memory`.
3. Write `infra/k8s/service.yaml`: `type: LoadBalancer`, `port: 80`,
   `targetPort: 8080`, `namespace: claims-api` — this is the exposure
   ADR-004 names as the accepted `tb-1` trust boundary; do not add
   auth/TLS here (out of scope per the spec's Won't Have).
4. Where `kubectl` is available: `kubectl apply --dry-run=client -f infra/k8s/`.
   Expected: all three resources validate with no schema errors.
5. Commit:
   ```
   git add infra/k8s/
   git commit -m "feat(claims-api): Deployment + LoadBalancer Service (REQ-305/306, ADR-004)"
   ```

## Task P9: GitHub Actions workflow (REQ-307/308, per ADR-003)

No xUnit test applies; "done" is the workflow YAML being syntactically
valid and the gating logic matching ADR-003 (unconditional build/test/
scan; deploy steps run only when OIDC secrets are present, skipped —
not failed — otherwise) **plus the plan-level branch restriction noted
in the Files section above.**

1. Write `.github/workflows/claims-api.yml`:
   ```yaml
   name: Claims API CI/CD

   on:
     pull_request:
       branches: [main]
     push:
       branches: [main]

   jobs:
     build-test-scan:
       name: Build, test, dependency scan
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-dotnet@v4
           with:
             dotnet-version: "8.0.x"
         - run: dotnet restore ClaimsApi.sln
         - run: dotnet build ClaimsApi.sln --configuration Release --no-restore
         - run: dotnet test ClaimsApi.sln --configuration Release --no-build
         - name: Vulnerable package scan
           run: dotnet list ClaimsApi.sln package --vulnerable --include-transitive

     provision-and-deploy:
       name: Push image, provision infra, deploy
       needs: build-test-scan
       runs-on: ubuntu-latest
       # github.ref == 'refs/heads/main' is a plan-level addition beyond
       # ADR-003's literal "OIDC secrets present" condition — see the
       # Files section note above.
       if: ${{ github.ref == 'refs/heads/main' && secrets.AZURE_CLIENT_ID != '' }}
       permissions:
         id-token: write
         contents: read
       steps:
         - uses: actions/checkout@v4
         - uses: azure/login@v2
           with:
             client-id: ${{ secrets.AZURE_CLIENT_ID }}
             tenant-id: ${{ secrets.AZURE_TENANT_ID }}
             subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
         - name: Provision infra (Bicep)
           run: az deployment group create --resource-group claims-api-rg --template-file infra/bicep/main.bicep
         - name: Build and push image
           run: |
             az acr build --registry "${{ vars.ACR_NAME }}" --image claims-api:${{ github.sha }} -f src/ClaimsApi/Dockerfile .
         - name: Deploy to AKS
           run: |
             az aks get-credentials --resource-group claims-api-rg --name "${{ vars.AKS_NAME }}"
             kubectl apply -f infra/k8s/
   ```
   `vars.ACR_NAME`/`vars.AKS_NAME` are **repository variables, not
   secrets** (names aren't sensitive) — they're set out-of-band by
   whoever provisions the subscription/resource group, consistent with
   the spec's Assumptions section ("A target Azure subscription and
   resource group will be supplied externally"). No task in this plan
   creates them; they're external configuration, not a plan deliverable.
2. Validate YAML syntax: `python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/claims-api.yml'))"`.
   Expected: no exception.
3. Commit:
   ```
   git add .github/workflows/claims-api.yml
   git commit -m "feat(claims-api): CI/CD workflow, OIDC-gated deploy (REQ-307/308, ADR-003)"
   ```

## Task P10: Full quality-gate pass

1. Run `bash scripts/run-quality-gates.sh` from the repo root. Expected:
   - `scripts/quality-gates-other.sh` no longer prints
     `SKIP dotnet gates (no .csproj found yet)` — it now finds
     `src/ClaimsApi/ClaimsApi.csproj` and `tests/ClaimsApi.Tests/ClaimsApi.Tests.csproj`
     within its `-maxdepth 3` search and runs `dotnet format --verify-no-changes`,
     `dotnet build`, `dotnet test`.
   - All pytest/governance checks remain green (unchanged by this work).
   - The pre-existing `check-traceability.sh` failure
     (`verification/example.dfy` proves REQ-000, which no live spec
     defines) is unrelated to this plan and was already present on
     `main` before this branch — do not attempt to fix it here.
2. If `dotnet format --verify-no-changes` fails on formatting drift,
   run `dotnet format` once, re-run the gate, and commit the
   formatting fix separately:
   ```
   git add -u
   git commit -m "style(claims-api): dotnet format"
   ```
3. This is the last task on `impl/plan-1-claims-status-api` before
   moving to VALIDATE (`phase/validate`) per the pipeline table.
