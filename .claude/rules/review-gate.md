# Human Review Gate

**This rule loads at every session start.**

Before proceeding from one phase to the next:
1. Ensure all work is committed to the phase branch.
2. Push the branch and open a PR to `main`.
3. Run the verifier from a separate terminal, OUTSIDE any Claude Code session
   (a Claude session cannot spawn another): `scripts/run-verifier.sh <PR-number>`.
   It runs the verifier skill in full mode via `claude -p` on your Claude Code
   subscription and posts the findings to the PR. Add `--persona` for persona
   mode. CI's "Verifier findings posted" check stays red until the findings
   comment exists; CI itself runs only the mechanical gates (quality gates,
   Dafny, governance tests). The check attests only that findings were posted
   — it does not parse the verdict.
4. If critical or high findings exist (verdict REQUEST_CHANGES), address them
   and re-run the verifier. Enforcing the verdict is the human reviewer's job
   (step 5), not CI's.
5. A human reviewer must approve the PR before merge.
6. After merge, create the next phase branch from updated `main`.

This is the operational rule for `art-branch-as-state` and `art-review-gate`.

## Phase sequence (10 phases)

```
phase/spec       (BRAINSTORM + SPECIFY)
phase/arch       (ARCHITECTURE)
phase/plan       (PLAN + TASKS + ANALYZE)
impl/plan-N-<name> (IMPLEMENT, one branch per impl plan)
phase/validate   (VALIDATE)
phase/security   (SECURITY)
phase/release    (RELEASE)
```

Out-of-cycle:

```
phase/retro-YYYY-MM-DD     (Retrospective, per art-retrospective-cadence)
impl/sec-<finding-id>      (SECURITY back-edge, per art-threat-driven-security)
```

## Tool sequence per phase

See `CLAUDE.md` pipeline table.

## Phase-specific gate rules

- ARCHITECTURE exit gate: every `[verifiable]` or `[verifiable-model]` REQ maps to a kernel module (`art-kernel-boundary`); threat model has ≥1 trust boundary, ≥1 asset with CIA, ≥1 STRIDE category per external-facing data-flow element.
- SECURITY exit gate: zero `severity: critical, status: open`; zero `severity: high, status: open`; accepted/deferred mediums cap respected (`art-threat-driven-security`).
- RELEASE exit gate: gates green; `dist/manifest.json` checksums verify; manifest content transcribed into the release notes; tag `v<version>` exists and is signed — annotated permitted only with the GPG fallback recorded in known-limitations; known-limitations references every SEC-NNN with accepted/deferred status (`art-release-readiness`).

## Back-edge protocol

If SECURITY surfaces a finding with `severity: critical` or `severity: high` that requires code change:

1. Spawn `impl/sec-<finding-id>` from `main` (while the `phase/security` PR remains open).
2. Fix using TDD (`art-test-first`).
3. PR to `main`, merge.
4. Re-run VALIDATE locally; fix any regressions on the same branch.
5. Resume `phase/security`, rebase on `main`, append the fix record to the review and update the disposition to `status: fixed`.
6. SECURITY completes only when every critical and high finding is `fixed`.

Mediums never trigger the back-edge; they go straight to disposition.

## Patch tier (sanctioned light path)

For small changes that don't warrant the full 7-PR pipeline (added 2026-06-09;
the unsanctioned alternative is bypassing the state machine entirely, which is
how SpecFlow v1 died):

- **Qualifies:** a change whose spec delta touches no `[verifiable*]` REQ, no
  kernel-boundary module, and no trust boundary in the threat model.
- **Process:** ONE PR containing the spec delta + implementation (TDD) +
  green `run-quality-gates.sh`. The verifier still runs
  (`scripts/run-verifier.sh <PR>`); a human still approves.
- **Does not qualify:** anything touching `[verifiable*]` REQs, ADRs, the
  constitution, security artifacts, or release artifacts — those take the
  full phase path.

## Minor exception (bounded)

Doc-only fixes (typos, formatting, broken links) may merge directly to `main`
without a PR (`art-review-gate`) — bounded to changes that touch **no** files
under `src/`, `verification/`, `scripts/`, `.github/`, `.claude/`, and no
phase artifacts (specs, ADRs, plans, security, releases). If a "minor" change
needs any of those, it is patch tier at minimum.
