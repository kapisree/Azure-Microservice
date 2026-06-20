---
id: ADR-004
status: accepted
date: 2026-06-20
addresses: [REQ-306]
---

# ADR-004: Accept public, unauthenticated `LoadBalancer` exposure as a named trust boundary for v1

## Context
The spec's brainstorm rejected `ClusterIP` in favor of `LoadBalancer`
exposure for verifiability (a public IP is the simplest way to confirm
a deploy worked end-to-end without port-forwarding). The fresh-eyes
review (`docs/reviews/2026-06-20-claims-status-api-spec-review.md`,
convergent finding #1) rated the resulting exposure — plain HTTP, no
auth, no rate limiting, and a full-dataset-dump `GET /claims` — **High**
severity, and the spec's own Risks section flagged that the
ARCHITECTURE threat model "must still carry this forward as a named
trust boundary," not silently re-defer it. This ADR is where that
obligation gets formally discharged at the ARCHITECTURE layer.

## Decision
Keep the `LoadBalancer` `Service` (REQ-306) as specified, but formally
record the resulting exposure as **trust boundary `tb-1`** in the threat
model (`docs/architecture/2026-06-20-claims-status-api-threat-model.md`),
with STRIDE coverage for every external data-flow element it exposes
(`dfe-1` claimId lookup, `dfe-2` full-dataset list, `dfe-3` health
check). The architectural
decision is to **accept** this boundary's current risk for v1 — not to
add TLS/auth/rate-limiting now — because:
1. The spec's Won't Have section already excludes auth, TLS, and rate
   limiting from this version's scope by design.
2. The only data ever served is synthetic/seeded (no real claimant
   data, per Compliance) — a documentation-level control, explicitly
   called out as *not* code-enforced, so this acceptance is conditional
   and revocable.
3. This pattern is explicitly marked **not production- or PHI-safe as
   written** in the spec's Risks section and in `Won't Have`, so a
   future reuse of this pattern with real data requires revisiting this
   ADR, not silently inheriting it.

**This acceptance is provisional, not a settled disposition.** Per
`art-threat-driven-security`, the binding severity for `tb-1`/`dfe-1`/
`dfe-2` is the CVSS v4.0 base score a second reviewer assigns during the
SECURITY phase — not this ADR's informal "accept for v1" framing. If
that scoring lands **critical or high**, `art-threat-driven-security`
requires the finding reach `status: fixed` (it cannot be accepted or
deferred), which overrides this ADR's stance: the back-edge protocol
(`.claude/rules/review-gate.md`) triggers, and the fix (not this
acceptance) becomes binding. This ADR's "accept" stance is only
honorable if SECURITY scores the exposure ≤ medium.

## Consequences
- The exposure is no longer an undocumented gap deferred indefinitely —
  it is a named, accepted architectural risk with explicit revocation
  conditions (real/PHI data ever entering the system).
- SECURITY phase (`art-threat-driven-security`) inherits `tb-1` directly
  from this ADR and the threat model rather than having to first
  establish that the boundary exists.
- If a future spec reuses this AKS/Bicep/CI pattern for a service that
  *does* handle real claimant or health data, that spec must supersede
  this ADR (frontmatter `supersedes:`) rather than copy the Deployment/
  Service manifests as-is.

## Alternatives Considered
- **Switch to `ClusterIP` + port-forward for verification**: rejected —
  reintroduces the manual-step friction the brainstorm already rejected,
  and doesn't actually eliminate the underlying gap (still no auth once
  a real ingress is added later) — it only hides it.
- **Add TLS/auth now, ahead of scope**: rejected — out of scope per the
  spec's Won't Have; would also require an identity provider decision
  this spec explicitly defers, expanding scope well beyond "demonstrate
  the pipeline on a small cloud-native service."
