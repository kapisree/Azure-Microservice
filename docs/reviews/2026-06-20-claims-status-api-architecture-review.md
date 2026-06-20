---
date: 2026-06-20
target: docs/adr/002-minimal-api-domain-seam.md, docs/adr/003-acr-aks-managed-identity.md, docs/adr/004-public-loadbalancer-exposure.md, docs/architecture/2026-06-20-claims-status-api-overview.md, docs/architecture/2026-06-20-claims-status-api-threat-model.md (pre-approval, phase/arch)
reviewers:
  - persona: azure-cloud-architect
  - persona: security-architect
  - persona: service-consumer
---

# Fresh-Eyes Review — Claims Status API Architecture

Three personas read the ARCHITECTURE-phase artifacts against the
already-approved spec (`docs/specs/2026-06-20-claims-status-api-design.md`)
and its fresh-eyes review. `service-consumer` replaces the
healthcare-claims-domain-expert from the SPEC review per
`.claude/commands/architecture.md`'s instruction to include at least
one customer/consumer persona — domain-modeling questions were already
settled in SPECIFY and don't recur at this layer.

## Convergent findings (≥2 reviewers)

| # | Finding | Severity | Flagged by | Recommendation |
|---|---|---|---|---|
| 1 | STRIDE coverage for `dfe-1`/`dfe-2` omits **D** (Denial of Service), even though "no rate limiting" is a named non-goal applying to the *whole* public surface, not just `/health` (`dfe-3`) | Low–Medium | architect + security | Add `D` to `dfe-1` and `dfe-2`'s `stride_per_element`, with the same "none — out of scope" mitigation already recorded for `dfe-3`, so the gap is visible per-element instead of only on the health check. |

## Per-reviewer findings

### Azure Cloud Architect

- **Kernel boundary correctly vacuous.** `kernel_modules: []` in the overview is right given the spec waives `[verifiable]`/`[verifiable-model]` entirely — ADR-002 says so explicitly, which is the correct way to satisfy `art-kernel-boundary` without padding the doc with a module that doesn't exist.
- **External dependencies are real and justified.** ACR, AKS, and the OIDC federation each have a one-line justification tied to a concrete REQ. No padding, no vague "Azure services" catch-all.
- **DoS gap (convergent #1):** the missing `D` letters on `dfe-1`/`dfe-2` are the only real gap I found. The mermaid diagrams and component breakdown match the spec's components 1:1 — nothing invented, nothing missing.
- **Verdict:** Approve, with the `D` addition requested before PLAN.

### Security Architect

- **ADR-004 is the right artifact at the right layer.** It formally accepts the trust-boundary risk the SPEC review flagged as High, names the exact revocation condition (real/PHI data), and points SECURITY phase at `tb-1`/`dfe-1`/`dfe-2` directly — this is what "carry forward as a named trust boundary" (the spec's own Risk mitigation) should look like. It does not try to silently re-soften the severity; it explicitly distinguishes "today's actual exposure" from "what this asset class would rate if real data were substituted in."
- **DoS gap (convergent #1):** same finding as the architect — worth fixing because `dfe-1`'s unauthenticated per-id enumeration and `dfe-2`'s full-dump are themselves a volumetric DoS/scraping vector even before considering `/health`.
- **Repudiation correctly has no entry, but the omission should be explained, not silent.** No STRIDE element lists `R`. For a fully unauthenticated, mutation-free, unlogged API, there's no identity to repudiate and no consequential action to deny — so omitting `R` is defensible, but the threat model doesn't say *why*, and a SECURITY-phase reader can't tell "considered and inapplicable" apart from "forgotten." One sentence would close this. (Not counted as a blocking finding — low severity, doc-only.)
- **OIDC boundary (`tb-2`/`dfe-4`) is correctly scoped.** Spoofing and tampering are the right STRIDE categories for a federated-identity trust boundary; the mitigations (subject-claim scoping, no static secret, branch protection as an operational control) are accurate and don't overclaim what this repo's artifacts control versus what's configured externally.
- **Verdict:** Approve, with the `D` addition requested; the repudiation rationale is a nice-to-have, not a blocker.

### Service Consumer

- **No change to the contract I depend on.** `GET /claims/{claimId}`, `GET /claims`, `GET /health` still return the same status codes and bodies the spec promised (200/400/404, problem-details on error) — ARCHITECTURE didn't quietly add an auth header requirement or change a response shape on me.
- **The public-IP exposure decision (ADR-004) doesn't change my integration today**, but I appreciate that it's now written down *as a decision* rather than left as an unexamined gap — if I were ever asked to point a real client at this pattern with real data, ADR-004 is exactly the document that would stop me before I did something unsafe.
- **No new questions.** Nothing in these artifacts changes how I'd call this API.
- **Verdict:** Approve — nothing here affects the consumer-facing contract.

## Disposition

| Finding | Severity | Recommended action | Disposition |
|---|---|---|---|
| `dfe-1`/`dfe-2` missing `D` (DoS) in STRIDE coverage | Low–Medium | Add `D` to both elements' `stride_per_element` with the existing "out of scope" mitigation | **fixed:** threat model frontmatter and STRIDE-coverage narrative updated to include `D` on `dfe-1` and `dfe-2`. |
| Repudiation (`R`) omission undocumented | Low | One-line rationale in the threat model narrative | **fixed:** added one sentence explaining `R` is inapplicable (no auth, no mutation, nothing to repudiate). |

Both fixes are documentation-only — no architectural decision changes as a
result of this review. Carried into the threat model directly before
push, consistent with how the SPEC-phase review's fixes were folded in.

## Sign-offs

- [x] Azure Cloud Architect — approved, with the `D`-coverage addition requested before PLAN
- [x] Security Architect — approved, with the `D`-coverage addition requested and the repudiation rationale as a nice-to-have
- [x] Service Consumer — approved, no consumer-facing impact
