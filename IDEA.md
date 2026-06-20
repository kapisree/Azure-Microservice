# IDEA.md

## Idea
A small .NET/C# REST API — a claims/order-status lookup service — built end-to-end with Claude Code using this repo's spec-driven pipeline. The service is containerized and deployed to Azure Kubernetes Service (AKS), with infrastructure provisioned as code via Bicep and a GitHub Actions pipeline handling build, test, image push, and deployment.

## Objective / Done Looks Like
A caller can hit a REST endpoint (e.g. `GET /claims/{id}` or `GET /orders/{id}/status`) and get back the current status of a claim or order, with proper 404/error handling for unknown IDs. The service runs as a container in AKS behind a Kubernetes Service/Ingress, is deployed via a GitHub Actions workflow that builds the image, pushes it to a registry (e.g. ACR), and applies the Bicep-provisioned infrastructure, with no manual `kubectl`/`az` steps required for a routine release. Before this exists, there is no deployable reference service in this repo; after, there's a working AKS-hosted .NET API with a repeatable, automated deployment path.

## Target Users
- **Service consumer / API caller** — an internal client or front-end that needs to look up claim/order status programmatically; cares about response correctness, latency, and clear error semantics.
- **Developer extending the service** — someone adding endpoints or business logic later; cares about a clean, testable .NET project structure and a fast local dev loop.
- **Platform/DevOps owner** — responsible for the AKS cluster and CI/CD pipeline; cares about reproducible infra (Bicep), secure secrets handling, and a pipeline that fails loudly on regressions.

## Non-Goals (Explicit Out-of-Scope)
- No real claims/order data source — this version uses an in-memory or mock data store, not a production database or external system integration.
- No authentication/authorization scheme beyond what's needed to demonstrate the pattern (no full identity provider integration in v1).
- No multi-region or HA AKS topology — a single cluster/namespace is sufficient.
- No autoscaling tuning, service mesh, or advanced observability stack (tracing/metrics dashboards) in v1.
- No write/mutation endpoints — read-only lookup only.

## Constraints
- Language/runtime: .NET / C# (ASP.NET Core Web API).
- Containerization: Docker, image built in CI and pushed to a registry (e.g. Azure Container Registry).
- Deployment target: Azure Kubernetes Service (AKS).
- Infrastructure-as-Code: Bicep for all Azure resources (AKS cluster, ACR, networking, etc.).
- CI/CD: GitHub Actions for build, test, containerize, and deploy stages.
- Development process: must follow this repo's spec-driven pipeline (BRAINSTORM → SPECIFY → ARCHITECTURE → PLAN → IMPLEMENT → VALIDATE → SECURITY → RELEASE) using Claude Code throughout.
