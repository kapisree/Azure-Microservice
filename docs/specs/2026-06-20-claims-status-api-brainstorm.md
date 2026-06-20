---
type: brainstorm
phase: BRAINSTORM
spec: 2026-06-20-claims-status-api
status: accepted
created: "2026-06-20"
---

# Brainstorm — Claims Status API

## Goal
A small .NET/C# REST API for looking up insurance claim status, built through this factory's spec-driven pipeline, containerized, and deployed to AKS via Bicep + GitHub Actions — demonstrating the full pipeline on a real (if deliberately small) cloud-native service rather than the pure-function demo.

## Constraints
- Domain: insurance claims (not generic orders) — chosen for a concrete, recognizable status enum.
- Read-only: no mutation endpoints.
- In-memory seeded data only — no real database or external claims system integration.
- No authentication/authorization in this version.
- .NET / C# (ASP.NET Core), stack recorded as `other` in `.stack` (no built-in dotnet preset in `scripts/init-project.sh`).
- No formal verification ([verifiable]/[verifiable-model]) — this project's logic doesn't involve auth, payment calculation, data-integrity state machines, or crypto in a way that warrants a Dafny model; tests are the only verification layer.
- Deployment target is real Azure infra (Bicep + AKS), but the GitHub Actions deploy stages must be gated on Azure OIDC secrets being present — this session has no live Azure subscription, so the pipeline must be fully defined without assuming one exists.

## Alternatives considered

**Domain:**
- Generic "case" abstraction — rejected: less concrete, doesn't read as a real lookup service.
- Order status — rejected in favor of insurance claims (user preference); both were viable, claims chosen.

**API internal structure:**
- **B — Controllers + Service/Repository layers**: rejected — conventional layered Web API is more files/boilerplate than 3 endpoints warrant.
- **C — Vertical-slice per endpoint**: rejected — good isolation but unconventional ceremony for this small a surface.
- **A — Minimal API + thin domain seam** (chosen): top-level Minimal API endpoint mapping, DI'd against an `IClaimsRepository` interface backed by an in-memory store. Smallest footprint while keeping the repository and endpoint-mapping units independently testable.

**Kubernetes Service exposure:**
- ClusterIP (internal-only, more realistic posture) — considered but rejected for v1: requires port-forwarding to verify the deploy worked.
- LoadBalancer (chosen): public IP via Azure Load Balancer, simplest to verify end-to-end after a deploy.

## Decision
Build a single ASP.NET Core Minimal API project (`ClaimsApi`) with three endpoints (`GET /claims/{claimId}`, `GET /claims`, `GET /health`), an in-memory seeded repository, Docker multi-stage build, Bicep-provisioned ACR + AKS (managed identity, no static registry credentials), Kubernetes Deployment+Service (LoadBalancer) with health-probe wiring, and a GitHub Actions workflow covering build/test/containerize unconditionally and push/provision/deploy gated on Azure OIDC secrets.

## Hand-off
SPECIFY phase turns this into `docs/specs/2026-06-20-claims-status-api-design.md` with REQ-300 through REQ-308 covering the API endpoints, container, infra, and pipeline — none tagged `[verifiable]`/`[verifiable-model]`.
