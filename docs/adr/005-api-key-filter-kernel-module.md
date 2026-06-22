---
id: ADR-005
status: accepted
date: 2026-06-22
addresses: [REQ-309, REQ-310, REQ-311]
---

# ADR-005: `Authorize` predicate as a kernel module behind an `IEndpointFilter` scoped to `/claims`

## Context
REQ-309 is the first `[verifiable-model]` requirement this product
introduces — ADR-001/ADR-002 explicitly waived `art-kernel-boundary`'s
req_map for the base spec (no verifiable REQs existed). This ADR is
where that boundary gets drawn for the first time on this product, and
where the `IEndpointFilter`-on-route-group mechanism (already chosen at
SPEC layer) gets its kernel-module/non-kernel split made explicit, since
the spec's auth-before-routing invariant (REQ-309) depends on exactly
where that split falls.

## Decision
Split the authentication surface into a small kernel module and a
non-kernel filter shell around it:

- **Kernel module — `src/ClaimsApi/ApiKeyFilter.cs`, `Authorize`
  predicate.** A pure function `Authorize(string? presented, string
  configured) -> bool` that the Dafny proof in
  `verification/claims_api_auth/` models as
  `Authorize(presented, configured) == (presented == configured)`,
  plus the auth-before-routing precedence invariant. This is the entire
  kernel boundary for this feature — REQ-309's `req_map` in
  `docs/architecture/2026-06-21-claims-status-api-auth-overview.md`
  covers exactly this one module.
- **Non-kernel shell — the `IEndpointFilter` registered on
  `MapGroup("/claims")`.** Reads the `X-Api-Key` header (or its
  absence) and the configured key from `IConfiguration`
  (`ApiKeySettings.Value`, REQ-314), calls `Authorize` via
  `CryptographicOperations.FixedTimeEquals` (REQ-309's postcondition;
  timing behavior is explicitly out of the Dafny proof's scope per the
  spec's Verification scope note), and on failure short-circuits with
  the REQ-311 `401`/`WWW-Authenticate` response before the route
  handler — and therefore before any model-bound route-parameter
  parsing — ever runs. This shell is the **external dependency crossing
  the kernel boundary**: it owns reading the configured key from
  configuration and is what the overview's `external_dependencies`
  entry justifies, so the kernel module itself never touches
  `IConfiguration` and the proof's precondition can state "a configured
  key value exists" as a given rather than a hidden side effect.
- **Binding constraint the kernel boundary depends on:** the route
  group's `claimId` parameter must stay `string`-bound and be parsed
  manually inside the handler (unchanged from ADR-002/the base plan).
  Retyping it to `Guid claimId` or adding a `:guid` route constraint
  would let ASP.NET Core's model binder produce a `400` before the
  filter runs, which would execute outside this kernel module entirely
  and silently break REQ-309's proven precedence invariant. This ADR
  records the constraint as architectural, not merely a spec note, so
  IMPLEMENT and any future refactor treat it as load-bearing.

## Consequences
- The kernel boundary for this product is now non-empty: exactly one
  module, `src/ClaimsApi/ApiKeyFilter.cs`'s `Authorize` predicate,
  satisfying `art-kernel-boundary`'s req_map for REQ-309.
- REQ-310 (health-check exemption) and REQ-311 (response shape) are
  consequences of where the filter is scoped and what it returns on
  failure, not separate kernel modules — they're TDD-only per the
  spec's own tagging note, covered here because the mechanism decision
  (route-group-scoped filter) is shared.
- A future requirement that needs more than "one shared secret, exact
  match" (e.g. multi-key, scoped keys, an identity provider) supersedes
  this ADR rather than extending `Authorize` in place, since the proof
  model is specifically `presented == configured`, not a more general
  authorization relation.
- If IMPLEMENT ever needs the `claimId` route parameter typed as `Guid`
  for an unrelated reason, that change must come back through this ADR
  (supersede or amend), not land silently in `Program.cs`, because it
  invalidates the precedence invariant's proof-to-code mapping.

## Alternatives Considered
- **`[Authorize]`-style attribute/middleware spanning the whole
  pipeline**: rejected — ASP.NET Core's built-in authentication
  middleware is designed around `ClaimsPrincipal`/schemes, far more
  machinery than a single shared-secret comparison needs, and would
  run before routing in a way that's harder to scope to exactly
  `/claims` without also touching `/health`.
- **Inline the comparison directly in each handler** (no filter,
  no separate module): rejected — duplicates the check across
  `GET /claims` and `GET /claims/{claimId}`, and gives the proof no
  single function to model; REQ-309's invariant becomes two invariants
  that could drift independently.
- **Model the entire `IEndpointFilter` (header parsing, `Results.Problem`
  construction, `FixedTimeEquals` call) inside the kernel boundary**:
  rejected — `art-formal-verification`'s `[verifiable-model]` scope is
  the authorization predicate and precedence ordering, not HTTP-shape
  concerns (REQ-311) or BCL timing behavior; pulling them in would make
  the kernel module larger than what the proof actually establishes,
  diluting what "inside the kernel" means.
