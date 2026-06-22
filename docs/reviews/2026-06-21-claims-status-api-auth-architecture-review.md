---
date: 2026-06-21
target: docs/adr/004-public-loadbalancer-exposure.md (amendment), docs/adr/005-api-key-filter-kernel-module.md, docs/architecture/2026-06-21-claims-status-api-auth-overview.md, docs/architecture/2026-06-21-claims-status-api-auth-threat-model.md (pre-PR, phase/arch)
reviewers:
  - persona: azure-cloud-architect
  - persona: security-architect
  - persona: service-consumer
---

# Fresh-Eyes Review — Claims Status API Authentication Architecture

Three personas read the ARCHITECTURE-phase artifacts for REQ-309..314
against the already-approved spec
(`docs/specs/2026-06-21-claims-status-api-auth-design.md`), independently.
Same persona set as the base spec's architecture review
(`docs/reviews/2026-06-20-claims-status-api-architecture-review.md`) —
`service-consumer` again replaces a domain-expert persona since no new
domain-modeling questions arise at this layer.

## Convergent findings (≥2 reviewers)
None reached convergence across all three personas — each reviewer's
findings were specific to their lens. No item below was independently
flagged by more than one persona.

## Per-reviewer findings

### Azure Cloud Architect
- **(High) Namespace-existence ordering gap.** REQ-312/313 assert
  "Secret applied before Deployment," but neither REQ-313 nor the
  original overview draft stated that the `claims-api` namespace must
  itself be (idempotently) applied first, and the `CLAIMS_API_KEY`
  fail-fast guard wouldn't catch a missing-namespace failure on a fresh
  cluster. **Fixed:** overview's cicd component now states the
  namespace-then-Secret-then-Deployment order explicitly as a sequencing
  requirement for IMPLEMENT.
- **(Medium) `external_dependencies` omitted the GitHub Actions secret
  store itself.** The CI secret (`CLAIMS_API_KEY`) is the first crossing
  in the key's custody chain and the highest-value target, but wasn't
  separately justified. **Fixed:** added as its own entry in the
  overview's frontmatter.
- **(Low) Diagram didn't show the fail-fast guard's failure path.**
  **Fixed:** added an explicit `Guard -->|fail| Abort` edge.
- Kernel-module scoping (ADR-005's pure-predicate split) and
  diagram/frontmatter consistency both checked out — no changes needed.
- **Verdict:** non-blocking; both findings addressed before PR.

### Security Architect
- **(Medium) `dfe-6`'s "no DoS" framing left out a real effect.** The
  auth check is a net DoS *improvement* for `dfe-1`/`dfe-2` (rejects
  floods before the expensive full-dataset enumeration), not just
  neutral. **Fixed:** added to the threat model's `dfe-6` D entry,
  explicitly not claimed as a designed mitigation.
- **(Medium) Superseding the base threat model's stale "Mitigation:
  none today" via a side-note in a different file, without touching the
  base document, risked a reader getting the wrong picture from the
  base file alone.** **Fixed:** annotated `dfe-1`/`dfe-2`'s Information
  Disclosure entries directly in
  `docs/architecture/2026-06-20-claims-status-api-threat-model.md` with
  a 2026-06-21 amendment note pointing at `dfe-6`.
- **(Low) `api-key-secret`'s A:M rating presumes REQ-313(d)'s
  rollout-restart is implemented, which isn't true yet.** **Fixed:**
  asset entry now states this is architecture intent pending
  VALIDATE/SECURITY confirmation, not a settled rating.
- ADR-004's amendment language checked for over-claiming ("fixes
  tb-1") — none found; correctly frames the boundary as narrowed, not
  closed, with SECURITY's CVSS score still binding over the ADR's
  stance.
- SEC-001 reconciliation is correctly flagged forward (spec Open
  Question #4, ADR-004 amendment) but not started this round — noted as
  a real risk of being forgotten, not a defect in this round's scope.
- **Verdict:** non-blocking; both Medium findings addressed before PR.

### Service Consumer
- **(Medium) `claimId` string-binding fragility (ADR-005) wasn't
  visible anywhere a consumer-facing engineer would naturally read.**
  The 401-before-400 guarantee depends entirely on an implementation
  choice three documents deep; nothing told a consumer the guarantee
  isn't structurally unbreakable. **Fixed:** added a sentence to the
  overview's Data flow section naming this dependency and that
  tests/Dafny — not the type system — are what catch a regression.
- Walked the full 401-vs-400 precedence path (spec → ADR-005 → overview
  → mermaid diagram) and found it logically consistent; `WWW-Authenticate`
  header value and the "never distinguish missing vs wrong" guarantee
  are stated identically everywhere; `/health` and already-authorized
  traffic are both correctly described as unchanged. No findings on any
  of these.
- Noted ADR-005's date (2026-06-21) is one day after the spec/overview
  filenames (2026-06-21) — flagged as a sequencing nit, not an error
  (architecture work legitimately followed spec approval by a day).
  No change needed.
- **Verdict:** non-blocking; finding addressed before PR.

## Disposition

| Finding | Severity | Recommended action | Disposition |
|---|---|---|---|
| Namespace-existence ordering not stated as a CI sequencing requirement | High | State explicit apply order in overview | **fixed:** overview's cicd component states namespace → Secret → Deployment order |
| `external_dependencies` omitted the GitHub Actions secret store | Medium | Add as its own justified entry | **fixed:** added to overview frontmatter |
| `dfe-6`'s DoS entry omitted a real (beneficial) side effect | Medium | Name the effect without claiming it as a designed mitigation | **fixed:** added to threat model |
| Base threat model's `dfe-1`/`dfe-2` "none today" left unedited and contradicted by the new doc | Medium | Annotate the base document in place | **fixed:** amendment notes added to base threat model |
| `api-key-secret`'s A:M availability rating presumes an unimplemented control | Low | Flag as provisional pending VALIDATE/SECURITY | **fixed:** asset entry updated |
| Diagram didn't show the fail-fast guard's failure path | Low | Add an explicit fail edge | **fixed:** diagram updated |
| `claimId` binding fragility invisible to a consumer-facing reader | Medium | One sentence in the overview's consumer-facing data-flow text | **fixed:** added |

All findings were Medium or lower except one High (namespace ordering),
and all were cheap documentation/diagram fixes — none required
re-deciding ADR-004's or ADR-005's actual decisions. No finding
contradicted a claim in the approved spec or implied a control exists
that the spec doesn't actually require.

## Sign-offs
- Azure Cloud Architect: approved, findings addressed.
- Security Architect: approved, findings addressed.
- Service Consumer: approved, finding addressed.
