---
date: 2026-06-20
target: docs/specs/2026-06-20-claims-status-api-design.md (status: draft, pre-approval)
reviewers:
  - persona: azure-cloud-architect
  - persona: security-architect
  - persona: healthcare-claims-domain-expert
---

# Fresh-Eyes Review — Claims Status API Spec

This is a fresh-eyes read of the SPECIFY-phase artifact before approval, not the formal SECURITY-phase review (that happens after ARCHITECTURE/PLAN/IMPLEMENT, per the pipeline). Three personas read `docs/specs/2026-06-20-claims-status-api-design.md` and the brainstorm independently.

## Convergent findings (≥2 reviewers)

| # | Finding | Severity | Flagged by | Recommendation |
|---|---|---|---|---|
| 1 | Service is exposed over plain HTTP (`Service` type `LoadBalancer`, port 80, no TLS) with no auth, no rate limiting, and a full-dump list endpoint (`GET /claims`) — for a service explicitly framed as a *claims* (and, per this review's brief, healthcare-claims-adjacent) reference pattern | **High** | architect + security + domain expert | Spec should state explicitly, in writing, that this surface is **not production/PHI-safe as-is** — and name what's missing (TLS, auth, rate limiting) — so the pattern can't be silently copied into a real deployment later. |
| 2 | No resource requests/limits on the Kubernetes `Deployment` (REQ-305) and no image vulnerability scanning in the CI workflow (REQ-307/308) | Medium | architect + security | Add resource requests/limits to REQ-305's acceptance criteria; add a container/dependency scan step to REQ-307 (doesn't need Azure credentials, so it can run unconditionally like the rest of build/test). |
| 3 | The spec never states which insurance line of business this models (health/medical vs. auto/property), yet is being reviewed by a *healthcare* claims expert and lives in a repo that templates future projects | Medium | security + domain expert | One line resolving this ambiguity — either "this models a generic/health-adjacent claim and intentionally avoids any HIPAA-covered data" or pick a vertical explicitly. Affects whether "no PHI" is an assumption or a designed-in constraint. |

## Per-reviewer findings

### Azure Cloud Architect

- **Resource requests/limits missing.** REQ-305 specifies probes but not CPU/memory requests/limits on the container. Without them, a single pod can starve the node or get OOM-killed unpredictably under any load — cheap to fix now (a few YAML lines), expensive to debug later. Recommend adding to REQ-305's acceptance criteria.
- **ACR SKU and image retention unspecified.** REQ-304 doesn't say Basic/Standard/Premium, and there's no image-cleanup policy. For a demo, Basic SKU with no retention policy is fine — but worth one line in the spec or an Open Question so it's a decision, not a default nobody chose.
- **Kubernetes namespace unspecified.** REQ-305/306 implicitly deploy to `default`. Minor, but a named namespace (e.g. `claims-api`) is a one-line improvement and standard practice — low cost to specify now.
- **`LoadBalancer` cost/quota note.** Azure now defaults to Standard SKU load balancers, which carry their own cost and a regional quota. Not a blocker, but the spec's "Open Questions" should mention it alongside the already-flagged node-size placeholder, since both are "confirm against real subscription constraints" items.
- **Bicep validation without credentials.** Good catch already in the spec's Risks section (`az bicep build`/`what-if` as a credential-free check) — no change needed, just noting it holds up under this lens.
- **Verdict:** Infra shape (ACR + AKS + managed identity, no static creds) is sound. The gaps above are real but cheap; none block moving to ARCHITECTURE. Recommend folding the resource-limits and namespace items into REQ-305 before PLAN, since they're free now and costly to retrofit after IMPLEMENT.

### Security Architect

- **No TLS on a publicly routable endpoint.** This is the headline finding (see convergent #1). The spec's existing Risk #2 acknowledges "no auth" but understates the actual exposure: combined with `GET /claims` returning the *entire* dataset unauthenticated and un-rate-limited, anyone with the IP can scrape every seeded record in one request — that's a stronger statement than "guessing one GUID," and the spec should say so plainly rather than soften it to "Low" severity. I'd rate the *current* exposure Low only because the data is synthetic and the project's own non-goals forbid real data — but that protection is a documentation promise, not a code-enforced control. Recommend the spec say so explicitly: severity is conditional on "synthetic data only" continuing to hold.
- **No image/dependency scanning in CI.** REQ-307/308 run `dotnet build`/`test` but nothing checks the base image or NuGet packages for known CVEs. This doesn't need Azure credentials (e.g. `dotnet list package --vulnerable`, or a registry-side scan once pushed) so there's no reason to gate it behind the OIDC-secrets condition like the deploy steps are. Recommend adding as an unconditional CI step.
- **Logging is unspecified.** Nothing in the spec says what the implementation may or may not log. Cheap insurance: one line stating logs may include `claimId` and `status` but never the full problem-details body verbatim from internal exceptions (consistent with the existing "no stack trace in response" rule, extended to logs).
- **Secrets/auth posture otherwise clean.** OIDC federated identity (no static cloud credentials), ACR admin disabled, managed-identity `AcrPull` — all correct and consistent with `art-secrets-hygiene`. No notes.
- **Verdict:** Nothing here blocks ARCHITECTURE, but finding #1 should be addressed in the spec text now (it's a documentation fix, not a design change) so the ARCHITECTURE-phase threat model inherits an honest framing instead of having to first correct the spec's own risk rating.

### Healthcare Claims Domain Expert

- **Status enum is a simplified subset of real claims-adjudication states, and the spec doesn't say so.** Real claims lifecycles commonly include a "pended" / "additional info requested" state and partial-approval outcomes, and denied claims usually have an appeal path — none of which are modeled here. That's a reasonable simplification for a demo, but right now a reader could mistake `Submitted/UnderReview/Approved/Denied/Paid` for a domain-accurate model rather than an intentional simplification. Recommend one line under Non-Goals: "This enum is a simplified subset of real claims-adjudication states; it does not model partial approvals, info-request holds, or appeals."
- **Bare GUID as the only identifier is a real but accepted gap.** In practice, claims lookups are almost always scoped by some relationship the caller already has (claimant, policy, provider) rather than a bare opaque id with no context — you don't typically hand a stranger a GUID and call it a lookup key. This is consistent with the earlier "Minimal" response-shape decision and the explicit non-goal of skipping claimant/policy data, so I'm not asking to add fields — just noting the spec should state the assumption explicitly: *callers already possess the claimId from some other system; this API doesn't establish how that pairing happens.* (The spec's Assumptions section is the right place; it currently doesn't mention this.)
- **The "healthcare" framing vs. the spec's actual generic "insurance claims" framing is unresolved** (see convergent #3). If this is meant to be healthcare-claims-flavored at all, the complete absence of any HIPAA/PHI discussion — even a one-line "not applicable because no real claimant data ever enters this system" — is conspicuous by omission in a healthcare-adjacent reference pattern. The spec's existing Compliance line ("no real claimant data; sample/synthetic data only") is the right instinct but reads as incidental rather than a deliberate, named guardrail.
- **Verdict:** No blocking domain-modeling errors — the simplifications are reasonable for stated scope. The gap is entirely about the spec not *saying out loud* which simplifications it's making, which matters more here than in a typical CRUD demo because this artifact will likely be read later as a pattern to imitate.

## Disposition

| Finding | Severity | Recommended action | Disposition |
|---|---|---|---|
| No TLS / no rate limiting / full-dump list endpoint, framed as claims/healthcare pattern | High | Add explicit "not production/PHI-safe as-is" caveat to spec now (doc fix); carry the underlying gap into the ARCHITECTURE threat model as a named trust boundary | **fixed (spec):** Risks section rewritten with explicit "not production- or PHI-safe as written" caveat. Threat model (ARCHITECTURE phase) must still carry this forward as a named trust boundary. |
| Missing resource requests/limits, missing image/dependency scanning | Medium | Fold into REQ-305 and REQ-307 acceptance criteria before PLAN | **fixed:** REQ-305 now requires CPU/memory requests+limits and a dedicated namespace; REQ-307 now requires an unconditional dependency/image vulnerability scan. |
| Insurance vertical (health vs. generic) unresolved | Medium | One-line resolution in spec (Assumptions or Compliance) | **fixed:** Compliance section now states the domain is deliberately generic/non-health-specific and HIPAA is treated as not applicable to this version, with an explicit "do not reuse with real/PHI data as-is" caveat. |
| ACR SKU / retention, namespace, LB SKU/quota unspecified | Low | Add to Open Questions alongside the existing node-size placeholder | **fixed:** Open Questions #3 (ACR SKU/retention) and #4 (LB SKU/quota) added; namespace resolved directly in REQ-305 rather than left open. |
| Status enum is a simplification; bare GUID assumes out-of-band pairing | Low | One line each under Non-Goals / Assumptions | **fixed:** Won't Have gained a line naming the status enum as a deliberate simplification; Assumptions gained a line on out-of-band claimId acquisition. |

None of these are blocking — they're all cheap to fix in the spec text itself before it leaves draft status. The High finding is a documentation-honesty fix, not a design change: it doesn't require re-architecting anything in this draft, just naming the gap instead of letting the existing "Low severity" risk rating understate it.

## Sign-offs

- [x] Azure Cloud Architect — approved, with REQ-305 resource-limits and namespace additions requested before PLAN
- [x] Security Architect — approved, with the TLS/exposure caveat and CI scanning step requested before PLAN
- [x] Healthcare Claims Domain Expert — approved, with the simplification/assumption call-outs requested before PLAN
