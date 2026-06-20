# SpecFlow Factory Constitution

This file lists the twelve non-negotiable articles that govern every spec, plan, and PR in this repository. Read this first every session.

Each article has a stable **slug** (e.g., `art-kernel-boundary`). Verifier blocking findings cite article by slug, never by Roman numeral. Roman numerals are display-only and may be reassigned without breaking citations.

---

## I — Specification Primacy

```yaml
roman: I
slug: art-specification-primacy
title: Specification Primacy
status: active
```

Spec changes happen at the spec layer first; code regenerates to match the spec. No code change is valid without a corresponding spec entry.

**Why:** prevents code from drifting away from intent.
**How to apply:** every PR that changes `src/` must reference at least one `REQ-NNN`.

---

## II — Branch-as-State

```yaml
roman: II
slug: art-branch-as-state
title: Branch-as-State
status: active
```

No work on `main`. Each phase has a named branch. State of work is the set of open branches and their PR status. There is no out-of-band state file.

**Why:** branches and PRs are auditable, ordered, and tool-native.
**How to apply:** every phase transition is a PR to `main`. The 10 phase-branch names are listed in `.claude/rules/review-gate.md`.

---

## III — Review Gate

```yaml
roman: III
slug: art-review-gate
title: Review Gate
status: active
```

Every phase transition is a PR to `main` with verifier review and human approval. Minor doc-only fixes (typos, formatting) may merge directly to `main`.

**Why:** prevents bypass of the gates that the rest of the constitution depends on.
**How to apply:** if a change touches `src/`, `verification/`, or a phase artifact, it goes through a PR.

---

## IV — Test-First Discipline

```yaml
roman: IV
slug: art-test-first
title: Test-First Discipline
status: active
```

No production code is written before a failing test exists.

**Why:** tests written after code tend to confirm what the code does rather than what it should do.
**How to apply:** every PR that adds `src/` code must add a test in `tests/` in the same commit or earlier in the branch.

---

## V — Formal Verification

```yaml
roman: V
slug: art-formal-verification
title: Formal Verification
status: active
```

Two verification tags exist (amended 2026-06-09 per retro proposal #7):

- `[verifiable]` — full verification: a Dafny proof in `verification/` **plus** a runtime contract in `src/contracts/` extracted from the proven specification.
- `[verifiable-model]` — model verification: a Dafny proof in `verification/` that verifies a contract *model* of the behavior (not the production code), paired with a test that exercises the real implementation.

Runtime-contract extraction for `[verifiable]` is deferred to v3.2 (v3.1 spec Open Question #1a). Until it lands, tag requirements `[verifiable-model]` — the tag is honest about scope: the proof governs the model, tests govern the code.

**Why:** TDD proves cases pass; Dafny proves the contract is sound for all inputs.
**How to apply:** during IMPLEMENT, every `[verifiable]` or `[verifiable-model]` REQ adds a `.dfy` file; `[verifiable]` additionally adds a contract extraction step (v3.2+).

---

## VI — Architectural Kernel Boundary

```yaml
roman: VI
slug: art-kernel-boundary
title: Architectural Kernel Boundary
status: active
```

The ARCHITECTURE phase defines a verified-kernel boundary. Every `[verifiable]` or `[verifiable-model]` REQ maps to a module inside that boundary. Every external dependency crossing the boundary has a written justification in `docs/architecture/<spec-slug>-overview.md`.

**Why:** verification confidence is a function of where the kernel ends — without an explicit boundary, the kernel implicitly grows or shrinks per implementer mood.
**How to apply:** ARCHITECTURE-phase verifier rejects an overview whose `kernel_modules.req_map:` does not cover every `[verifiable]` or `[verifiable-model]` REQ.

---

## VII — Threat-Model Driven Security

```yaml
roman: VII
slug: art-threat-driven-security
title: Threat-Model Driven Security
status: active
```

The threat model produced in ARCHITECTURE (per `docs/architecture/<spec-slug>-threat-model.md`) drives the SECURITY phase. Every SECURITY finding cites a threat-model item, a CWE, or an OWASP reference. The severity rubric is **CVSS v4.0 base score**:

| Severity | CVSS v4.0 Base |
|---|---|
| critical | 9.0–10.0 |
| high | 7.0–8.9 |
| medium | 4.0–6.9 |
| low | 0.1–3.9 |

Severity is assigned during PR review by someone other than the finding's author when the team is ≥2 people. For solo teams, the author records `severity` provisionally; the next available second reviewer (next release cycle is acceptable) confirms or downgrades. Reclassification (downgrading) requires the second reviewer's handle and rationale to be recorded in the disposition's `rationale:` field. There is no CWE → CVSS auto-mapping (CWE is structural; CVSS is contextual).

**Empty reviews are valid.** A project with no findings produces `docs/security/<version>-review.md` whose body reads "0 findings; threat model `dfe-1..dfe-N` reviewed; no exposures identified." Manufacturing placeholder low-severity findings to "exercise" the gate is explicitly disallowed.

**Why:** absent a rubric, authors mark their own findings low and the gate becomes theater. Allowing empty reviews removes the perverse incentive to invent findings.
**How to apply:**
- SECURITY blocks RELEASE while any finding has `severity: critical, status: open` or `severity: high, status: open`.
- **Critical and high findings must reach `status: fixed`. They cannot be `accepted` or `deferred`** — RELEASE blocks if a critical or high carries those statuses regardless of expiry.
- **Mediums** with `status: accepted` or `status: deferred` are capped at 5 per release (override in `docs/security/RUBRIC.md`'s `medium_cap:` field).
- **Lows** do not count toward the cap and do not require an `expiry:`.

If SECURITY surfaces a critical or high finding requiring code change, spawn `impl/sec-<finding-id>` from main, fix with TDD, merge, re-run VALIDATE, then resume `phase/security` with `status: fixed`. SECURITY artifacts are versioned per re-entry.

---

## VIII — Release Readiness

```yaml
roman: VIII
slug: art-release-readiness
title: Release Readiness
status: active
```

RELEASE produces three docs (`<version>-notes.md`, `<version>-migration.md`, `<version>-known-limitations.md`), a tag `v<version>` (signed preferred; annotated permitted only when GPG is verifiably unavailable, in which case the fallback is recorded in `<version>-known-limitations.md` plus a follow-up to re-tag with `git tag -s`), and a dist artifact described by `dist/manifest.json` (one entry per file, with SHA-256 checksum + size). **The manifest content is transcribed into `<version>-notes.md`** (filename + sha256 + size for each artifact) so an auditor at the tag commit can verify checksums without re-running the hook (`dist/` itself is gitignored). The known-limitations doc auto-includes every `accepted` or `deferred` finding from `docs/security/<version>-disposition.md`.

**Why:** "tests pass" is not the same as "shipped"; the user needs the changelog, the migration steps, and a verifiable artifact whose checksums survive the gitignored dist directory.
**How to apply:** RELEASE-phase verifier blocks merge if any of: gates non-zero; manifest absent or checksums wrong; manifest content not transcribed into release notes; known-limitations missing a SEC-NNN that is accepted or deferred; tag missing; tag annotated without the fallback being recorded in known-limitations.

---

## IX — Repository Singleton

```yaml
roman: IX
slug: art-repository-singleton
title: Repository Singleton
status: active
```

All code, specs, plans, proofs, ADRs, threat models, and release artifacts live in this repository.

**Why:** split repos lose traceability and break the verifier's ability to walk REQ → ADR → task → code → proof.
**How to apply:** no PR introduces a remote submodule or split out a sub-project as its own repo.

---

## X — Naming & Tagging

```yaml
roman: X
slug: art-naming-tagging
title: Naming & Tagging
status: active
```

- Requirements: `REQ-NNN` (three-digit zero-padded, globally unique).
- Tasks: `TASK-NNN` (three-digit zero-padded, globally unique).
- ADRs: `ADR-NNN` (globally unique).
- Findings: `SEC-NNN` (globally unique).
- Verification tags: `[verifiable]` (full: proof + runtime contract) and `[verifiable-model]` (model proof + test) on requirements needing Dafny proofs — semantics in `art-formal-verification`.
- Article citations: `art-<kebab>` slug. Never Roman numeral.

**Why:** stable IDs make traceability mechanical.
**How to apply:** the verifier rejects PRs that introduce duplicate IDs or that cite a non-existent slug.

---

## XI — Secrets Hygiene

```yaml
roman: XI
slug: art-secrets-hygiene
title: Secrets Hygiene
status: active
```

Never commit `.env`, credentials, signing keys, or production tokens. Secrets live in GitHub Secrets; local development uses a `.env.local` listed in `.gitignore`.

**Why:** every credentialed commit is one `git log` away from a leak.
**How to apply:** `.gitignore` includes `.env*` (except `.env.example`); PR review rejects any commit containing `.env`.

---

## XII — Retrospective Cadence

```yaml
roman: XII
slug: art-retrospective-cadence
title: Retrospective Cadence
status: active
```

Run `/retrospective` after every RELEASE PR merges (recommended; not automatic). Retros land on a `phase/retro-YYYY-MM-DD` branch and produce `docs/retrospectives/YYYY-MM-DD-<topic>.md` proposing — not executing — updates to constitution, templates, and governance tests.

**Why:** a factory that doesn't fold lessons back drifts toward the lessons it forgot.
**How to apply:** after RELEASE PR merges, create `phase/retro-YYYY-MM-DD`, run `/retrospective`, open a PR with the proposed-changes doc. Apply changes in a follow-up PR if accepted.
