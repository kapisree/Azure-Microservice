---
type: spec
phase: SPEC
status: draft
created: "2026-06-20"
approved_by: ""
supersedes: ""
extends: ""
superseded_by: ""
extended_by: ""
---

# Claims Status API Specification

## Overview

A small ASP.NET Core (.NET) REST API that looks up insurance claim status from an in-memory, seeded data store. The service is containerized and deployed to Azure Kubernetes Service (AKS), with infrastructure provisioned as code via Bicep and a GitHub Actions workflow handling build, test, containerize, and (when Azure credentials are available) provision and deploy.

### Scope
In: Service consumer — gets a read-only HTTP lookup of claim status by id, plus a list endpoint. In: Platform/DevOps owner — gets reproducible infra (Bicep) and an automated pipeline (GitHub Actions) with no manual `kubectl`/`az` steps for a routine release. Out: Developer extending the service with new domain features — this spec only covers the read-only lookup surface; extension points are a future spec's concern, not this version's.

## Problem Statement

This repo's pipeline has only ever been exercised end-to-end against a pure-function demo (`greet`). This spec exercises the same 10-phase pipeline against a small but real cloud-native service — one with an HTTP surface, a container, cloud infrastructure, and a CI/CD pipeline — to demonstrate the factory works for that shape of project, not just pure functions.

## User Personas

### Persona: Service Consumer
- **Role:** An internal client or front-end calling the API.
- **Goal:** Look up a claim's current status programmatically.
- **Context:** Calls over HTTP/JSON; no auth in this version; needs clear status codes for "bad id" vs "unknown id" vs "found."
- **Success looks like:** A `GET /claims/{claimId}` call returns the right status code and a well-formed JSON body for every case (malformed id, unknown id, known id).

### Persona: Platform/DevOps Owner
- **Role:** Owns the AKS cluster and CI/CD pipeline.
- **Goal:** Ship a routine change with no manual cloud-console or CLI steps.
- **Context:** Cares about reproducible infra (Bicep), no static cloud credentials in CI (OIDC), and a pipeline that fails loudly on a broken build.
- **Success looks like:** Pushing a merged change to `main` results in a new image built, pushed, and rolled out to AKS automatically, with the deploy stage skipping cleanly (not failing) when Azure credentials aren't configured.

## Objectives

1. Provide a working read-only claim-status lookup API with clear, predictable error semantics.
2. Provide a Docker image and Kubernetes manifests that run that API on AKS, reachable via a public Load Balancer IP, with liveness/readiness wired to a health endpoint.
3. Provide Bicep templates that provision the ACR + AKS infrastructure the service needs, with no static registry credentials (managed identity `AcrPull`).
4. Provide a GitHub Actions workflow that builds and tests on every change, and pushes/provisions/deploys when Azure OIDC credentials are present — fully defined now, safely inert without live Azure access.

## Functional Requirements

### Must Have

- **REQ-300:** `GET /claims/{claimId}` returns claim status by id.
  - `claimId` is parsed as a GUID. If parsing fails: `400 Bad Request`, RFC 9457 problem-details body, `detail` states the id is not a valid GUID.
  - If parsing succeeds but no claim with that id exists in the repository: `404 Not Found`, problem-details body, `detail` states no claim was found for that id.
  - If a matching claim exists: `200 OK` with body `{ claimId, status, lastUpdated }`, where `status` is one of `Submitted`, `UnderReview`, `Approved`, `Denied`, `Paid` (serialized as a string).
- **REQ-301:** `GET /claims` returns `200 OK` with a JSON array of every seeded claim, same shape as the single-claim body. No pagination or filtering.
- **REQ-302:** `GET /health` returns `200 OK` with a trivial body (e.g. `{ "status": "healthy" }`), unconditionally — used as the Kubernetes liveness and readiness probe target.
- **REQ-303:** A multi-stage Dockerfile builds and runs the API as a non-root user, listening on port 8080, using the .NET SDK image to build/publish and the ASP.NET runtime image to run.
- **REQ-304:** Bicep templates provision an Azure Container Registry (admin access disabled) and an AKS cluster (system-assigned managed identity, RBAC enabled), with the AKS cluster's identity granted `AcrPull` on the registry — no static registry credentials anywhere in infra or CI.
- **REQ-305:** A Kubernetes `Deployment` manifest runs the container image with `livenessProbe` and `readinessProbe` both targeting `GET /health`.
- **REQ-306:** A Kubernetes `Service` of type `LoadBalancer` exposes the Deployment on port 80, forwarding to container port 8080.
- **REQ-307:** A GitHub Actions workflow runs `dotnet restore`/`build`/`test` on every push and pull request, independent of any Azure access.
- **REQ-308:** The same GitHub Actions workflow additionally builds and pushes the container image to ACR and applies the Bicep templates and Kubernetes manifests, but only when the required Azure OIDC secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) are present; when absent, these steps are skipped (not failed).

> No requirement in this spec is tagged `[verifiable]`/`[verifiable-model]` — none of this surface involves authentication, payment calculation, data-integrity state machines, or cryptography in a way that warrants a Dafny contract model (per `art-formal-verification`'s tagging guidance). Verification is TDD-only: every REQ above is covered by a corresponding test named in the implementation plan.

### Should Have
(none — the surface above is the complete v1 scope)

### Won't Have (this version)
- Authentication/authorization of any kind.
- Mutation endpoints (create/update/delete a claim).
- A real claims data source (database or external system integration).
- Pagination, filtering, or sorting on `GET /claims`.
- Multi-region or HA AKS topology, custom VNet, private cluster, service mesh, autoscaling tuning, or a metrics/tracing stack.

## Non-Functional Requirements
- **Performance:** No specific latency/throughput target — in-memory lookups are not expected to be a bottleneck at this scale.
- **Security:** No static cloud credentials in CI (OIDC federated identity only); no registry admin credentials (managed identity `AcrPull` only); no secrets or PII in the seeded sample data.
- **Scalability:** Out of scope — single small node pool, no autoscaling configuration.
- **Compliance:** None specified for this version (no real claimant data; sample/synthetic data only).

## Verification Identification

Two tags exist per `art-formal-verification`: `[verifiable]` (Dafny proof + runtime contract, contract extraction deferred to v3.2) and `[verifiable-model]` (Dafny proof of a contract model + tests of the implementation). Neither tag applies to any requirement in this spec — see the note under Functional Requirements.

## Success Metrics
1. All of REQ-300–302 have passing xUnit tests (unit + `WebApplicationFactory` integration) covering every status code path (200/400/404).
2. `docker build` produces a runnable image; the container serves `GET /health` as 200 locally.
3. `az deployment group create` with the Bicep templates succeeds against a real subscription (verified manually once Azure access exists, per Open Questions below).
4. The GitHub Actions workflow is green on build/test for every PR, and the gated deploy stages are present in the workflow file even though they don't execute in this session.

## Open Questions
1. This session has no live Azure subscription — the Bicep templates and the deploy stages of the GitHub Actions workflow can be written and code-reviewed, but cannot be exercised against real Azure infrastructure until credentials are provisioned out-of-band. Validating REQ-304/305/306/308 against a live cluster is deferred to whoever has subscription access.
2. Exact AKS node size/count (`Standard_B2s` ×1–2, proposed during brainstorming) is a placeholder default — confirm against actual budget constraints before RELEASE.

## Assumptions
- A target Azure subscription and resource group will be supplied externally; this spec's Bicep templates are subscription-agnostic (parameterized), not hardcoded to a specific tenant.
- GitHub Actions OIDC federation with Azure AD will be configured manually (`azure/login` action prerequisites) outside this repo's automation — this spec only consumes the resulting secrets.

## Risks
- **Risk:** Bicep/AKS/pipeline stages are unvalidated against real Azure until credentials exist. **Severity:** Medium. **Mitigation:** Code review + `az bicep build`/`what-if` (static validation) in CI as a cheap, credential-free correctness check; full validation deferred per Open Questions.
- **Risk:** `LoadBalancer` exposes the API on a public IP with no authentication. **Severity:** Low for this demo scope (no real data, explicitly out of scope per Non-Goals), but worth flagging now so it surfaces again at the SECURITY phase rather than being assumed away. **Mitigation:** Threat model (ARCHITECTURE phase) should treat the public endpoint as a trust boundary even though v1 has no auth.
