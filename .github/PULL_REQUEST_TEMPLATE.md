<!-- Phase PR checklist — delete sections that don't apply. -->

## What

<!-- One paragraph. Which phase / plan / fix is this? Reference REQ-NNN / ADR-NNN / SEC-NNN ids. -->

## Gate checklist

- [ ] `bash scripts/run-quality-gates.sh` exits 0 locally
- [ ] Verifier run from a terminal **outside** any Claude Code session: `scripts/run-verifier.sh <PR#>` (findings posted; "Verifier findings posted" check green)
- [ ] Constitution citations use `art-*` slugs, never Roman numerals

### Phase-specific (keep the one that applies)

**SPEC** — spec has lifecycle frontmatter (`status: draft`), Scope subsection, globally-unique REQ ids; `[verifiable*]` tags carry a Verification scope line.

**ARCHITECTURE** — every `[verifiable]`/`[verifiable-model]` REQ appears in a `kernel_modules.req_map`; threat model has ≥1 trust boundary, ≥1 asset with CIA, STRIDE per external element.

**PLAN/ANALYZE** — plan frontmatter has `spec:` + `decisions:`; `bash scripts/analyze-adr-plan-linkage.sh` passes; no implementation code inside the plan.

**IMPLEMENT** — failing test existed before each implementation change (`art-test-first`); `[verifiable*]` REQs have `.dfy` proofs with `// Proves:` headers; tests carry `# Covers:`.

**SECURITY** — zero open critical/high; mediums within `medium_cap` (docs/security/RUBRIC.md) with owner + expiry; every finding cites a threat-model item or CWE.

**RELEASE** — `bash scripts/verify-release.sh <version>` passes (tag, checksums, manifest transcription, SEC coverage).

## Tier

- [ ] Full phase PR
- [ ] Patch tier (spec-delta + impl + validate in one PR — see review-gate.md)
- [ ] Minor exception (doc-only; see bounds in review-gate.md)
