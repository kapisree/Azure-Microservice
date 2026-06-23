---
date: 2026-06-22
triggered_by: release
release_version: 0.2.0
proposes_changes_to:
  - constitution.md
  - docs/security/RUBRIC.md
  - scripts/run-verifier.sh
  - .github/workflows/verifier.yml  # only if Proposed Changes option (a) is accepted
  - .claude/rules/review-gate.md
illustrative_artifacts:
  - docs/plans/2026-06-21-claims-status-api-auth-plan.md
---

# Retrospective — SEC-006 process gap (v0.2.0)

First retrospective for this factory; no prior `docs/retrospectives/*.md`
exists, so `## Decisions on Prior Proposals` has nothing to walk (see that
section below).

## What Worked

- **The back-edge protocol worked exactly as designed.** SEC-006 (a
  fail-open authentication bypass: `ApiKeyFilter.Authorize("", "")`
  returned `true` because `CryptographicOperations.FixedTimeEquals`
  defines two zero-length spans as equal) was caught during the SECURITY
  phase review of v0.2.0, scored high under `art-threat-driven-security`,
  and routed through `impl/sec-sec-006` → failing test first
  (`Authorize_WithEmptyPresentedAndEmptyConfigured_MustNotAuthorize`) →
  minimal fix (`string.IsNullOrEmpty` guard) → Dafny model + lemma update
  → merge → VALIDATE re-run → resumed SECURITY with `status: fixed`. No
  step was skipped, and the constitution's "cannot be accepted or
  deferred" rule for high findings was never tested against pressure to
  cut a corner.
- **Branch-staleness precedent from PR #11 (`art-branch-as-state`) repeated
  correctly.** When PR #11's branch fell out of sync with a separately
  merged patch-tier fix, the fix was `git merge origin/main` onto the
  stale branch rather than re-deriving it — the same pattern this retro's
  own SEC-006 fix later didn't need, but worth naming as a worked pattern.
- **SEC-id uniqueness enforcement (`scripts/check-traceability.sh`) caught
  a real authoring mistake before it shipped.** Restating the four
  carried-forward findings (mutable Docker tags, unchecked vulnerability
  scan, AKS control-plane exposure, no rate limiting) verbatim with their
  original IDs in `docs/security/0.2.0-review.md` tripped the mechanical
  uniqueness gate locally, before any PR was opened — exactly the
  "mechanical, not by review" enforcement `CLAUDE.md`'s Architecture Notes
  describe for that script.
- **Two independent verifier passes (PR #14, PR #15) each surfaced real,
  distinct, non-blocking gaps** rather than rubber-stamping: the
  finding-count arithmetic error (claimed 7, body listed 6), the `AV:A`
  vs `AV:N` CVSS vector call (resolved in favor of `AV:N` once
  `infra/k8s/service.yaml`'s public `LoadBalancer` exposure was checked),
  and — independently, on two separate PRs — the same observation about
  an unenumerated `superseded` disposition status. Convergent findings
  across reviews are a signal the gap is real, not reviewer noise.

## What Didn't

1. **The empty-configured-key fail-open case was never tested until
   SECURITY, despite three earlier opportunities to catch it.**
   - PLAN (Task A2) specified `Authorize(string?, string) -> bool` and
     listed 5 tests, none of which exercised an empty `configured` value
     — only `presented is null` was treated as a guard case.
   - The Dafny model in `verification/claims_api_auth/api_key_filter.dfy`
     defined `Authorize(presented, configured) { presented == configured
     }` with no empty-string special-casing — and Dafny's own string
     equality makes `"" == ""` trivially true, so the proof was
     *consistent with* the bug rather than catching it. A proof that
     models the buggy behavior faithfully still says "verified."
   - ANALYZE's requirement-coverage check confirmed REQ-309 was "covered"
     by task A2/A4 without asking whether the covering tests/proof
     exercised the credential's *empty* state — coverage-by-task-mapping
     is not the same as coverage-by-edge-case.
   - `appsettings.json`'s production default for `ApiKey:Value` (`""`)
     was introduced in the same PR as the bug (Task A2) and reviewed
     without anyone connecting "the production default is empty" to "the
     auth predicate's behavior on empty input" until SECURITY.
2. **The verifier's documented scope (markdown-only diffs) has no
   process answer for code-only PRs, and this has now happened twice.**
   `scripts/run-verifier.sh` diffs `*.md` files only; a pure code+test PR
   (optionally +proof — PR #4's shell-only line-ending fix in the
   base-spec cycle had no proof, PR #13's SEC-006 fix did) finds nothing
   to review, posts nothing, and the "Verifier findings posted"
   CI check stays permanently red. Both times the resolution was "merge
   anyway, the check's failure here is a false negative" — a judgment
   call made ad hoc by a human each time, with no written rule backing
   it. `.claude/rules/review-gate.md` step 3 says findings must be
   posted and the check must turn green; in practice, for this PR shape,
   it never can.
3. **`status: superseded` was invented ad hoc and is not enumerated by
   `art-threat-driven-security`** (`open`/`fixed`/`accepted`/`deferred`).
   Used once, for SEC-001 (superseded by SEC-007 once this feature closed
   the gap SEC-001 originally described). The disposition document was
   transparent about the deviation and excluded it from cap accounting
   correctly, but two independent verifier passes (PR #14, PR #15) both
   flagged the same gap and both recommended a `/retrospective` — this
   document is that retrospective, arriving after the status was already
   used rather than before.
4. **A SECURITY-phase document restating carried-forward findings
   verbatim (with their original IDs) silently violates a mechanical
   gate** (`scripts/check-traceability.sh`'s SEC-id uniqueness check) —
   this was caught locally before PR #14 was opened, but only because
   `bash scripts/run-quality-gates.sh` happened to be re-run before
   pushing. There is no written guidance anywhere (`CLAUDE.md`, the
   RELEASE/SECURITY skill text, or `docs/security/RUBRIC.md`) telling an
   author *how* to reference a carried-forward finding from a new
   `<version>-review.md` without re-minting its ID — the correct pattern
   (describe by topic, keep the ID and full text in the original review
   file only) was discovered by trial and error against the failing
   script, not from documentation.

## Proposed Changes

1. **Amend `art-threat-driven-security` to enumerate a fifth disposition
   status: `superseded`.** Definition: a finding whose original wording no
   longer accurately describes the system because a later finding
   (recorded via a new `id:`) replaces it with a re-scoped equivalent. A
   `superseded` finding carries no `expiry:`, is excluded from the
   medium/critical/high cap accounting, and its YAML block must record
   `superseded_by: <new-id>`. Target: `constitution.md`'s
   `art-threat-driven-security` section + `docs/security/RUBRIC.md`.
   (Raised independently by the verifier on both PR #14 and PR #15.)
2. **Document, in `docs/security/RUBRIC.md` or a new "Carrying findings
   forward" subsection, the pattern for referencing unchanged
   carried-forward findings in a new `<version>-review.md` without
   re-minting their `SEC-NNN` IDs** — describe by topic/file, keep full
   text and the ID in the originating review document only, restate
   status/owner/expiry in the new disposition document (which
   `scripts/check-traceability.sh` does not scan). This is exactly the
   pattern this session converged on after a failed local gate run; it
   should not require rediscovery next release.
3. **Add an explicit fallback rule to `.claude/rules/review-gate.md` step
   3/4 for code-only PRs** (no markdown changed): either (a) document
   that `scripts/run-verifier.sh`'s "No markdown documents changed —
   nothing to verify" exit is itself a valid satisfied-by-design state,
   and have `scripts/run-verifier.sh` post a minimal attestation comment
   in that case (`<!-- specflow-verifier:none-applicable -->...`) so the
   `verifier-attestation` CI job in `.github/workflows/verifier.yml` can
   detect it and pass instead of permanently failing, or (b) extend the
   verifier's scope to review code diffs too when no markdown changed,
   per the skill's own "adversarial reviewer" charter. Caution on (a): the
   existing `verifier-attestation` CI grep (`grep -q 'specflow-verifier:'`,
   `.github/workflows/verifier.yml`) would match a `none-applicable`
   marker exactly as it matches real findings — so (a), if adopted as
   written, mechanically greenlights any zero-markdown PR, including
   `impl/*` IMPLEMENT-phase work, with zero adversarial review of the
   code/test/proof diff. Given SEC-006 was itself a code-only fix, this
   tradeoff should be weighed against `art-review-gate` before either
   option is adopted — see Open Question 1. A narrower version of (a),
   scoped only to `impl/sec-*` back-edge branches (which were reviewed
   once already, in the SECURITY phase that raised the finding), is
   likely safer than applying it to all code-only PRs.
4. **Add an explicit empty/default-credential test case to the PLAN
   template's task-authoring guidance** (or to `art-test-first`'s
   "How to apply" note) for any `[verifiable]`/`[verifiable-model]` task
   whose kernel module is a credential/authorization predicate: the task
   list must include a case exercising the predicate's behavior when the
   *configured* value is empty/default/unset, not only when the
   *presented* value is missing. This is the single change most likely to
   have caught SEC-006 before IMPLEMENT rather than during SECURITY.
   Target: whichever template or skill governs PLAN's task-authoring
   guidance (no per-spec template currently exists in this repo;
   `docs/plans/2026-06-21-claims-status-api-auth-plan.md` is listed under
   `illustrative_artifacts` in the frontmatter as the nearest concrete
   example of the gap — it is not a target this proposal edits
   retroactively).
5. **Require a Dafny model's empty/default-input behavior to be checked
   against the production default it will be compared to, as part of
   `art-formal-verification`'s "How to apply" note.** The
   `api_key_filter.dfy` proof was internally sound (it proved its model
   was total) but the model itself silently matched the bug; a proof
   that a model is consistent with a known-bad default doesn't surface
   that inconsistency on its own. Concretely: when a `[verifiable-model]`
   REQ's production code reads a configuration default, the model should
   include that default as a named case (e.g. an Dafny lemma like
   `EmptyConfiguredNeverAuthorizes`, which only exists in the *fixed*
   version of this proof) from the start, not added retroactively after
   SECURITY finds the gap.

## Decisions on Prior Proposals

No prior retrospective exists (`docs/retrospectives/` contained only
`README.md` before this document). Nothing to walk forward. This section
will carry this retrospective's own proposals forward for the *next*
retrospective to decide, per the mandatory closing-the-loop rule.

### Decisions on this retrospective's own proposals (added 2026-06-23, follow-up PR)

- **Proposal 1** (`superseded` status) — accepted (landed:
  `constitution.md`'s `art-threat-driven-security`,
  `docs/security/RUBRIC.md`).
- **Proposal 2** (carried-forward-finding ID pattern doc) — accepted
  (landed: `docs/security/RUBRIC.md`'s new "Carrying findings forward
  without re-minting IDs" section).
- **Proposal 3** (verifier fallback for code-only PRs) — accepted, but
  narrower than either option (a) or (b) as originally framed (landed:
  `scripts/run-verifier.sh`, `.claude/rules/review-gate.md`). Scoped to
  `impl/sec-*` and `patch/*` branches only, per Open Question #1's lean
  toward the narrower variant — both shapes had already received one
  round of human/SECURITY review before the branch existed. Plain
  `impl/*` IMPLEMENT branches are explicitly **not** covered; that part
  of Open Question #1 (and PR #4's precedent) remains open for a future
  retrospective.
- **Proposal 4** (empty/default-value test case requirement) — accepted,
  generalized per Open Question #2 rather than scoped to auth predicates
  only (landed: `constitution.md`'s `art-test-first`). No PLAN-specific
  template file exists in this repo to amend (speckit's `/speckit.plan`
  is external); the constitutional amendment is the binding guidance
  until one exists.
- **Proposal 5** (Dafny model must check the production default) —
  accepted (landed: `constitution.md`'s `art-formal-verification`).

## Open Questions

1. Should proposal 3's fallback (a minimal "not applicable" attestation
   comment for code-only PRs) be scoped narrowly to `impl/sec-*`
   back-edge branches, or to any PR with zero markdown changes
   (including ordinary `impl/*` IMPLEMENT-phase PRs)? The base-spec
   cycle's PR #4 (`patch/sh-line-endings`) suggests the latter, but that
   widens what "verified" means for ordinary IMPLEMENT work too — worth a
   second opinion before landing.
2. Proposal 4 (empty/default-credential test case in PLAN guidance) is
   specific to authorization predicates. Is there a more general
   principle here — e.g., "every `[verifiable*]` task list must include a
   case for each input's zero/default/empty value, not just
   null/missing" — that should be the actual constitutional amendment
   instead of a narrower auth-specific rule? Left open for whoever
   accepts proposal 4 to decide the generalization's scope.
3. This retrospective's own proposed amendments to `constitution.md`
   (proposal 1) and `art-formal-verification` (proposal 5) are themselves
   proposals, not edits — per this skill's contract, they require a
   follow-up PR to actually amend the constitution if accepted. Who signs
   off on constitutional amendments in a solo-team context, and is that
   sign-off itself a `/retrospective`-cadence decision or a standing
   human-reviewer call independent of this cadence?
