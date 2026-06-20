# SpecFlow Factory v3.1

Short description: Verified spec-to-code pipeline with SpecKit + Superpowers + Dafny formal verification, plus architecture / security / release gates.

## Start Every Session Here

Read `constitution.md` first. It defines the twelve non-negotiable articles. Cite article slugs (e.g., `art-kernel-boundary`) — never Roman numerals.

## Repo Rule

All code, specs, plans, proofs, ADRs, threat models, and release artifacts live in this repository (Article `art-repository-singleton`).

## Stack

- Language: {{STACK}} (configured at init time)
- Testing: (configured at init time)
- Verification: Dafny (for `[verifiable]`/`[verifiable-model]` requirements, Article `art-formal-verification`)
- CI: GitHub Actions
- AI: Claude Code (Opus for specs/reviews, Sonnet for implementation)

## Pipeline (10 phases)

| Phase | Branch | Primary tool(s) | Output |
|---|---|---|---|
| BRAINSTORM | `phase/spec` | `/superpowers:brainstorming` | brainstorm notes |
| SPECIFY | `phase/spec` | `/speckit.specify`, `/speckit.clarify` | `docs/specs/<spec>.md` |
| ARCHITECTURE | `phase/arch` | `/architecture` | ADR(s), `docs/architecture/<spec-slug>-overview.md`, `docs/architecture/<spec-slug>-threat-model.md` |
| PLAN | `phase/plan` | `/speckit.plan` + `/superpowers:writing-plans` | `docs/plans/<plan>.md` (PLAN consumes ADRs; does not re-derive architecture) |
| TASKS | `phase/plan` | `/speckit.tasks` | task list inside the plan |
| ANALYZE | `phase/plan` | `/speckit.analyze` + verifier skill | analysis report + ADR→PLAN linkage check |
| IMPLEMENT | `impl/plan-N-<name>` | `/superpowers:subagent-driven-development`, TDD, Dafny | code + tests + proofs |
| VALIDATE | `phase/validate` | `scripts/run-quality-gates.sh` + verifier | green gate pass |
| SECURITY | `phase/security` | `/security-review` | `docs/security/<version>-review.md`, `docs/security/<version>-disposition.md` |
| RELEASE | `phase/release` | `/release` | `docs/releases/<version>-{notes,migration,known-limitations}.md`, signed tag, `dist/manifest.json` |

Back-edge: if SECURITY surfaces critical/high requiring code change, spawn `impl/sec-<finding-id>`, fix, merge, re-VALIDATE, resume SECURITY (Article `art-threat-driven-security`).

Out-of-cycle: `/retrospective` runs on `phase/retro-YYYY-MM-DD` (Article `art-retrospective-cadence`).

## Project Map

- `constitution.md` — twelve articles, read first
- `docs/specs/` — design specs and brainstorm output
- `docs/adr/` — architecture decision records (one per decision)
- `docs/architecture/` — overview + threat model per spec
- `docs/plans/` — implementation plans
- `docs/security/` — security review + disposition per release
- `docs/releases/` — release notes + migration + known-limitations per release
- `docs/retrospectives/` — periodic retros
- `docs/reviews/` — review syntheses
- `docs/dashboard/` — generated HTML dashboard (gitignored)
- `src/` — application code (incl. `src/contracts/` for extracted runtime contracts)
- `verification/` — Dafny proofs (`.dfy`)
- `tests/` — unit / integration / governance tests
- `scripts/` — automation (incl. `run-quality-gates.sh`)
- `schemas/` — spec templates
- `templates/` — starter templates

## Canonical Example

`docs/specs/2026-05-28-demo-greeting-design.md` and its derived artifacts demonstrate the full 10-phase pipeline. Use the demo as a structural template for new specs. The derived artifacts:

- BRAINSTORM: `docs/specs/2026-05-28-demo-greeting-brainstorm.md`
- SPECIFY: `docs/specs/2026-05-28-demo-greeting-design.md`
- ARCHITECTURE: `docs/adr/001-greeting-invariant.md`, `docs/architecture/2026-05-28-demo-greeting-overview.md`, `docs/architecture/2026-05-28-demo-greeting-threat-model.md`
- PLAN/TASKS: `docs/plans/2026-05-28-demo-greeting-plan.md`
- IMPLEMENT: `src/demo_greeting/`, `tests/demo_greeting/`, `verification/demo_greeting/`
- Fresh-eyes review: `docs/reviews/2026-05-28-v3.1-demo-review.md`
- SECURITY: `docs/security/0.0.1-demo-{review,disposition}.md`
- RELEASE: `docs/releases/0.0.1-demo-{notes,migration,known-limitations}.md`, tag `v0.0.1-demo`

## Critical Never-Do

- Never write code before a failing test exists (`art-test-first`).
- Never push directly to main (`art-branch-as-state`, `art-review-gate`).
- Never create a separate repository (`art-repository-singleton`).
- Never commit `.env` (`art-secrets-hygiene`).
- Never cite an article by Roman numeral (`art-naming-tagging`).
