---
id: ADR-002
status: accepted
date: 2026-06-20
addresses: [REQ-300, REQ-301, REQ-302]
---

# ADR-002: Minimal API with a thin `IClaimsRepository` domain seam

## Context
REQ-300/301/302 need three small read-only endpoints over an in-memory
seeded data store. The brainstorm (`docs/specs/2026-06-20-claims-status-api-brainstorm.md`)
already chose this over Controllers+Service/Repository layers and
vertical-slice-per-endpoint; ARCHITECTURE records the decision formally
so PLAN can consume it without re-deriving it.

## Decision
A single ASP.NET Core Minimal API project (`ClaimsApi`) maps three
top-level endpoints directly to handler delegates. Handlers are
constructor-injected (via DI) with an `IClaimsRepository` interface;
an in-memory implementation (`InMemoryClaimsRepository`) seeds fixed
sample data at startup. No controller classes, no service layer, no
repository abstraction beyond the one interface.

## Consequences
- Smallest reasonable footprint for 3 endpoints — no unused layering.
- `IClaimsRepository` is the only seam: endpoint-mapping logic and
  repository logic are independently unit-testable without standing up
  the full ASP.NET pipeline (`WebApplicationFactory` only needed for
  integration tests of status-code/JSON-shape behavior).
- Swapping the in-memory store for a real data source later (out of
  scope for this spec, per Won't Have) only requires a new
  `IClaimsRepository` implementation, not endpoint changes.
- No `[verifiable]`/`[verifiable-model]` kernel module results from this
  decision — the spec already waived formal verification for this
  surface (no auth/payment/integrity-state-machine/crypto), so
  `art-kernel-boundary`'s req_map requirement is vacuously satisfied.

## Alternatives Considered
- **Controllers + Service/Repository layers**: rejected — conventional
  layered Web API is more files/boilerplate than 3 endpoints warrant.
- **Vertical-slice per endpoint**: rejected — good isolation but
  unconventional ceremony for this small a surface.
