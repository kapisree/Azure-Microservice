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
ordering only. Runnable code, test bodies, Bicep/YAML content, and the
workflow file live in the IMPLEMENT phase, on a branch named
`impl/plan-1-claims-status-api`, one task at a time, TDD-first
(`art-test-first`) wherever a REQ describes runtime *behavior* (REQ-300/
301/302). REQ-303–308 describe infrastructure artifacts (container,
Bicep, k8s manifests, CI workflow) that have no unit-testable behavior of
their own; for those, "done" means the static/credential-free validation
named in the spec's Success Metrics (`docker build`, `az bicep build`,
`kubectl --dry-run=client`, workflow YAML lint) passes, not an xUnit test.

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
- `src/ClaimsApi/ClaimsApi.csproj` — `Microsoft.NET.Sdk.Web`, `net8.0`.
- `src/ClaimsApi/Program.cs` — Minimal API host; top-level statements
  plus a trailing `public partial class Program { }` so
  `WebApplicationFactory<Program>` in the test project can see it
  (the standard ASP.NET Core minimal-hosting test pattern).
- `src/ClaimsApi/ClaimStatus.cs` — enum: `Submitted`, `UnderReview`,
  `Approved`, `Denied`, `Paid`.
- `src/ClaimsApi/Claim.cs` — `record Claim(Guid ClaimId, ClaimStatus Status, DateTimeOffset LastUpdated)`.
- `src/ClaimsApi/IClaimsRepository.cs` — the ADR-002 domain seam:
  `Claim? GetById(Guid claimId)`, `IReadOnlyList<Claim> GetAll()`.
- `src/ClaimsApi/InMemoryClaimsRepository.cs` — `IClaimsRepository`
  implementation seeding a fixed in-memory list at construction.
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
  is product CI/CD, not factory governance.

## Task P1: Solution and project scaffolding

No REQ behavior is implemented in this task — it only creates enough of
a compilable, runnable host for later tasks to write failing tests
against. `dotnet new` scaffolds; this is setup, not implementation, so
`art-test-first` does not require a preceding failing test for it.

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
3. Delete the template's default `WeatherForecast`-style scaffolding if
   `dotnet new web` generated any (it shouldn't for the `web` template,
   but confirm `src/ClaimsApi/` contains only `ClaimsApi.csproj` and
   `Program.cs` before continuing).
4. Run `dotnet build` from the repo root. Expected: build succeeds, zero
   warnings about ambiguous startup.
5. Commit:
   ```
   git add ClaimsApi.sln src/ClaimsApi tests/ClaimsApi.Tests
   git commit -m "chore(claims-api): scaffold solution, Web + xUnit/WebApplicationFactory projects"
   ```

## Task P2: `GET /health` (REQ-302)

- [ ] **Step 1: Write the failing test** in
  `tests/ClaimsApi.Tests/HealthEndpointTests.cs`:
  ```csharp
  using System.Net;
  using Microsoft.AspNetCore.Mvc.Testing;
  using Xunit;

  public class HealthEndpointTests
  {
      [Fact]
      public async Task Health_ReturnsOk_WithHealthyBody()
      {
          using var factory = new WebApplicationFactory<Program>();
          using var client = factory.CreateClient();

          var response = await client.GetAsync("/health");

          Assert.Equal(HttpStatusCode.OK, response.StatusCode);
          var body = await response.Content.ReadAsStringAsync();
          Assert.Contains("\"status\":\"healthy\"", body);
      }
  }
  ```
- [ ] **Step 2: Run it, confirm it fails** — `dotnet test`. Expected:
  FAIL (404, no `/health` route mapped yet).
- [ ] **Step 3: Implement the minimal route** in `Program.cs`, between
  `builder.Build()` and `app.Run()`:
  ```csharp
  app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));
  ```
- [ ] **Step 4: Run `dotnet test`, confirm it passes.**
- [ ] **Step 5: Commit:**
  ```
  git add src/ClaimsApi/Program.cs tests/ClaimsApi.Tests/HealthEndpointTests.cs
  git commit -m "feat(claims-api): GET /health (REQ-302)"
  ```

## Task P3: Domain model + `IClaimsRepository` seam (per ADR-002)

- [ ] **Step 1: Write the failing unit tests** in
  `tests/ClaimsApi.Tests/InMemoryClaimsRepositoryTests.cs`:
  ```csharp
  using Xunit;

  public class InMemoryClaimsRepositoryTests
  {
      [Fact]
      public void GetAll_ReturnsSeededClaims_NonEmpty()
      {
          var repo = new InMemoryClaimsRepository();
          Assert.NotEmpty(repo.GetAll());
      }

      [Fact]
      public void GetById_KnownId_ReturnsMatchingClaim()
      {
          var repo = new InMemoryClaimsRepository();
          var seeded = repo.GetAll()[0];

          var found = repo.GetById(seeded.ClaimId);

          Assert.NotNull(found);
          Assert.Equal(seeded.ClaimId, found!.ClaimId);
      }

      [Fact]
      public void GetById_UnknownId_ReturnsNull()
      {
          var repo = new InMemoryClaimsRepository();
          Assert.Null(repo.GetById(Guid.NewGuid()));
      }
  }
  ```
- [ ] **Step 2: Run `dotnet test`, confirm it fails** (types don't
  exist yet — compile error counts as a failing test for this purpose).
- [ ] **Step 3: Implement** `src/ClaimsApi/ClaimStatus.cs`:
  ```csharp
  public enum ClaimStatus
  {
      Submitted,
      UnderReview,
      Approved,
      Denied,
      Paid
  }
  ```
  `src/ClaimsApi/Claim.cs`:
  ```csharp
  public record Claim(Guid ClaimId, ClaimStatus Status, DateTimeOffset LastUpdated);
  ```
  `src/ClaimsApi/IClaimsRepository.cs`:
  ```csharp
  public interface IClaimsRepository
  {
      Claim? GetById(Guid claimId);
      IReadOnlyList<Claim> GetAll();
  }
  ```
  `src/ClaimsApi/InMemoryClaimsRepository.cs`:
  ```csharp
  public class InMemoryClaimsRepository : IClaimsRepository
  {
      private readonly List<Claim> _claims = new()
      {
          new Claim(Guid.NewGuid(), ClaimStatus.Submitted, DateTimeOffset.UtcNow.AddDays(-5)),
          new Claim(Guid.NewGuid(), ClaimStatus.UnderReview, DateTimeOffset.UtcNow.AddDays(-3)),
          new Claim(Guid.NewGuid(), ClaimStatus.Approved, DateTimeOffset.UtcNow.AddDays(-1)),
          new Claim(Guid.NewGuid(), ClaimStatus.Denied, DateTimeOffset.UtcNow.AddDays(-2)),
          new Claim(Guid.NewGuid(), ClaimStatus.Paid, DateTimeOffset.UtcNow),
      };

      public Claim? GetById(Guid claimId) => _claims.FirstOrDefault(c => c.ClaimId == claimId);

      public IReadOnlyList<Claim> GetAll() => _claims;
  }
  ```
- [ ] **Step 4: Run `dotnet test`, confirm all three pass.**
- [ ] **Step 5: Commit:**
  ```
  git add src/ClaimsApi/ClaimStatus.cs src/ClaimsApi/Claim.cs src/ClaimsApi/IClaimsRepository.cs src/ClaimsApi/InMemoryClaimsRepository.cs tests/ClaimsApi.Tests/InMemoryClaimsRepositoryTests.cs
  git commit -m "feat(claims-api): domain model + IClaimsRepository seam (ADR-002)"
  ```

## Task P4: `GET /claims/{claimId}` (REQ-300)

**Interfaces consumed:** `IClaimsRepository.GetById(Guid)` from Task P3.

- [ ] **Step 1: Write the failing integration tests** in
  `tests/ClaimsApi.Tests/ClaimsEndpointsTests.cs`:
  ```csharp
  using System.Net;
  using Microsoft.AspNetCore.Mvc.Testing;
  using Xunit;

  public class ClaimsEndpointsTests
  {
      private static WebApplicationFactory<Program> CreateFactory() => new();

      [Fact]
      public async Task GetClaimById_MalformedGuid_Returns400ProblemDetails()
      {
          using var factory = CreateFactory();
          using var client = factory.CreateClient();

          var response = await client.GetAsync("/claims/not-a-guid");

          Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
      }

      [Fact]
      public async Task GetClaimById_UnknownGuid_Returns404ProblemDetails()
      {
          using var factory = CreateFactory();
          using var client = factory.CreateClient();

          var response = await client.GetAsync($"/claims/{Guid.NewGuid()}");

          Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
      }

      [Fact]
      public async Task GetClaimById_KnownGuid_Returns200WithClaimBody()
      {
          using var factory = CreateFactory();
          using var client = factory.CreateClient();

          var all = await (await client.GetAsync("/claims")).Content.ReadAsStringAsync();
          // Extract a real claimId from the list to avoid hardcoding seed data here.
          var firstId = System.Text.Json.JsonDocument.Parse(all).RootElement[0]
              .GetProperty("claimId").GetGuid();

          var response = await client.GetAsync($"/claims/{firstId}");

          Assert.Equal(HttpStatusCode.OK, response.StatusCode);
          var body = await response.Content.ReadAsStringAsync();
          Assert.Contains("\"status\"", body);
      }
  }
  ```
  (The third test depends on `GET /claims` from Task P5 to fetch a real
  id; if P5 isn't implemented yet, this one test will also fail for
  that reason — acceptable, since both endpoints land before this task
  is considered done. Run both together; do not mark P4 complete until
  all three pass.)
- [ ] **Step 2: Run `dotnet test`, confirm `GetClaimById_*` tests fail**
  (no `/claims/{claimId}` route yet).
- [ ] **Step 3: Implement** in `Program.cs`, registering the repository
  and mapping the route:
  ```csharp
  builder.Services.AddSingleton<IClaimsRepository, InMemoryClaimsRepository>();
  ```
  ```csharp
  app.MapGet("/claims/{claimId}", (string claimId, IClaimsRepository repo) =>
  {
      if (!Guid.TryParse(claimId, out var id))
      {
          return Results.Problem(
              detail: $"'{claimId}' is not a valid GUID.",
              statusCode: StatusCodes.Status400BadRequest);
      }

      var claim = repo.GetById(id);
      if (claim is null)
      {
          return Results.Problem(
              detail: $"No claim found for id '{id}'.",
              statusCode: StatusCodes.Status404NotFound);
      }

      return Results.Ok(new { claimId = claim.ClaimId, status = claim.Status.ToString(), lastUpdated = claim.LastUpdated });
  });
  ```
- [ ] **Step 4: Run `dotnet test`, confirm it passes** (once P5 also
  lands `GET /claims`).
- [ ] **Step 5: Commit:**
  ```
  git add src/ClaimsApi/Program.cs tests/ClaimsApi.Tests/ClaimsEndpointsTests.cs
  git commit -m "feat(claims-api): GET /claims/{claimId} (REQ-300)"
  ```

## Task P5: `GET /claims` (REQ-301)

**Interfaces consumed:** `IClaimsRepository.GetAll()` from Task P3.

- [ ] **Step 1: Add the failing test** to
  `tests/ClaimsApi.Tests/ClaimsEndpointsTests.cs`:
  ```csharp
  [Fact]
  public async Task GetClaims_Returns200WithArrayOfAllSeededClaims()
  {
      using var factory = CreateFactory();
      using var client = factory.CreateClient();

      var response = await client.GetAsync("/claims");

      Assert.Equal(HttpStatusCode.OK, response.StatusCode);
      var body = await response.Content.ReadAsStringAsync();
      var array = System.Text.Json.JsonDocument.Parse(body).RootElement;
      Assert.True(array.GetArrayLength() >= 1);
  }
  ```
- [ ] **Step 2: Run `dotnet test`, confirm it fails** (404, no
  `/claims` route).
- [ ] **Step 3: Implement** in `Program.cs`:
  ```csharp
  app.MapGet("/claims", (IClaimsRepository repo) =>
      Results.Ok(repo.GetAll().Select(c => new { claimId = c.ClaimId, status = c.Status.ToString(), lastUpdated = c.LastUpdated })));
  ```
- [ ] **Step 4: Run `dotnet test`, confirm every test in the project
  passes** (this also unblocks Task P4's third test).
- [ ] **Step 5: Commit:**
  ```
  git add src/ClaimsApi/Program.cs tests/ClaimsApi.Tests/ClaimsEndpointsTests.cs
  git commit -m "feat(claims-api): GET /claims (REQ-301)"
  ```

## Task P6: Multi-stage Dockerfile (REQ-303)

No xUnit test applies to a Dockerfile; "done" is the spec's own Success
Metric #2 (`docker build` succeeds, container serves `/health` as 200
locally).

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
2. From the repo root: `docker build -f src/ClaimsApi/Dockerfile -t claims-api:local .`
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
explicitly deferred per the spec's Open Question #1).

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
2. Run `az bicep build --file infra/bicep/main.bicep`. Expected: compiles
   to ARM JSON with no errors. (If the `az` CLI isn't installed in this
   environment, note that as a deferred local-validation gap consistent
   with the spec's existing Open Question #1 — do not skip writing the
   template itself.)
3. Commit:
   ```
   git add infra/bicep/main.bicep
   git commit -m "feat(claims-api): Bicep ACR + AKS, managed identity AcrPull (REQ-304, ADR-003)"
   ```

## Task P8: Kubernetes manifests — Deployment + Service (REQ-305/306, per ADR-004)

No xUnit test applies; "done" is `kubectl apply --dry-run=client -f
infra/k8s/` succeeding (static manifest validation, no live cluster
required).

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
4. Run `kubectl apply --dry-run=client -f infra/k8s/`. Expected: all
   three resources validate with no schema errors. (If `kubectl` isn't
   installed locally, this is a deferred local-validation gap, same
   category as Task P7's `az` dependency — write the manifests
   regardless.)
5. Commit:
   ```
   git add infra/k8s/
   git commit -m "feat(claims-api): Deployment + LoadBalancer Service (REQ-305/306, ADR-004)"
   ```

## Task P9: GitHub Actions workflow (REQ-307/308, per ADR-003)

No xUnit test applies; "done" is the workflow YAML being syntactically
valid and the gating logic matching ADR-003 exactly (unconditional
build/test/scan; deploy steps run only when OIDC secrets are present,
skipped — not failed — otherwise).

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
   `vars.ACR_NAME`/`vars.AKS_NAME` are repository variables (not
   secrets — names aren't sensitive) set out-of-band, consistent with
   the spec's Assumptions (subscription/resource group supplied
   externally).
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
