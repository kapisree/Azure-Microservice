# SpecFlow Factory v3.1

Short description: Verified spec-to-code pipeline with SpecKit + Superpowers + Dafny formal verification, plus architecture / security / release gates.

## Start Every Session Here

Read `constitution.md` first. It defines the twelve non-negotiable articles. Cite article slugs (e.g., `art-kernel-boundary`) — never Roman numerals.

## Repo Rule

All code, specs, plans, proofs, ADRs, threat models, and release artifacts live in this repository (Article `art-repository-singleton`).

## Stack

- Language: .NET / C# (ASP.NET Core), recorded as stack `other` in `.stack` — no built-in dotnet preset in `scripts/init-project.sh`, so `scripts/quality-gates-other.sh` is hand-written (dotnet format / build / test) rather than generated
- Testing: `dotnet test` (xUnit, once the project scaffold exists under `src/`)
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
| ANALYZE | `phase/plan` | `/speckit.analyze` + verifier skill | analysis report (`docs/plans/<spec-slug>-analysis.md`, frontmatter `for_spec:` not `spec:` — see Architecture Notes) + ADR→PLAN linkage check |
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

## Common Commands

- Run everything CI runs (pytest + Dafny + governance tests + per-stack hook): `bash scripts/run-quality-gates.sh`
- Run Python tests only: `python -m pytest tests/ -q`
- Run a single test: `python -m pytest tests/demo_greeting/test_greeting.py::test_greet_world -v`
- Run one governance test directly: `bash tests/governance/test_onboarding_surface.sh`
- Verify all Dafny proofs: `dafny verify $(find verification -name '*.dfy')`
- Verify a single proof: `dafny verify verification/demo_greeting/greeting.dfy`
- Check REQ/ADR/SEC ID uniqueness and proof↔spec traceability: `bash scripts/check-traceability.sh`
- Check ADR→PLAN linkage (ANALYZE gate): `bash scripts/analyze-adr-plan-linkage.sh`
- Run the verifier against a PR — **outside** any Claude Code session, a session can't spawn another: `bash scripts/run-verifier.sh <PR-number>` (add `--persona` for persona mode)
- Render the pipeline dashboard / a single doc: `bash scripts/render-dashboard.sh`, `bash scripts/render-doc.sh <file>`
- Initialize a downstream product from this template (writes `.stack`, creates pipeline dirs): `bash scripts/init-project.sh`
- Install template tooling deps: `pip install -r scripts/requirements.txt`

Dafny is a hard dependency, not optional, as long as any `.dfy` file exists under `verification/` — `run-quality-gates.sh` fails the gate (not skips) if `.dfy` files are present but the `dafny` binary is missing. The shipped demo (`verification/demo_greeting/`) means this repo currently requires Dafny installed.

## Architecture Notes

- **Traceability chain**: `REQ-NNN` (spec) → `ADR-NNN` (architecture) → task (plan) → `src/` implementation + `tests/` + `verification/*.dfy` proof + `src/contracts/` runtime contract (for `[verifiable]`, deferred to v3.2) or just a test (for `[verifiable-model]`). `scripts/check-traceability.sh` enforces ID uniqueness and proof↔spec linkage mechanically; `scripts/analyze-adr-plan-linkage.sh` enforces the ADR→plan link; the verifier skill enforces everything else by review.
- **ANALYZE reports use `for_spec:` in frontmatter, never `spec:`**: `scripts/analyze-adr-plan-linkage.sh` globs `docs/plans/*.md` and treats any file carrying a `spec:` key as a plan needing ADR coverage in its `decisions:` field. An analysis transcript has no `decisions:` of its own, so a `spec:` key there fails the gate as an uncovered plan; `for_spec:` records the same source-spec link without tripping that check, and the script's own no-silent-skip reporting names the file explicitly (`SKIP (no spec: frontmatter — outside the gate)`) so the omission stays visible rather than silent.
- **Verification is three-layered, never one proof = done**: a Dafny proof only establishes that a *contract model* is total/sound for all inputs (`verification/`), not that the production code is correct. A runtime contract (`src/contracts/`, full `[verifiable]` tag only) enforces that proven contract at the code boundary. Tests (`tests/`) verify the actual implementation for concrete cases. See `verification/README.md` and `src/contracts/README.md` for the extraction convention (`Proves:` / `Extracted from:` headers, checked by CI).
- **`scripts/run-quality-gates.sh` is the single source of truth for "green"** — it runs pytest, then Dafny, then every `tests/governance/test_*.sh`, then an optional generated per-stack hook (`scripts/quality-gates-<stack>.sh`, written by `init-project.sh` based on `.stack`). `.github/workflows/ci.yml` invokes this exact script; there is no separate CI-only check, so a local green run means CI will also be green.
- **Governance tests are tests about the factory's own process compliance**, not the product — e.g. `test_onboarding_surface.sh` fails if README/`init-project.sh` drift from the current pipeline version, `test_constitution_articles.sh` fails if `constitution.md` doesn't have exactly 12 articles with unique `art-*` slugs. They run inside the same quality-gate pass as unit tests, so process drift breaks CI the same way a broken test would.
- **The verifier runs outside Claude Code on purpose**: `.claude/skills/verifier` is invoked via `claude -p` from `scripts/run-verifier.sh` in a plain terminal, because a running Claude Code session cannot spawn another one. It posts findings as PR comments, satisfying `.github/workflows/verifier.yml`'s "Verifier findings posted" check — that check only confirms a findings comment exists, it does not parse or enforce the verdict (REQUEST_CHANGES vs APPROVE); enforcing the verdict is the human reviewer's job.
- **This repo is itself the template, now initialized for the Claims Status API product**: `.stack` records stack `other` (.NET/C#); everything under `src/`, `tests/`, `verification/` outside `demo_greeting/` remains a placeholder (`.keep`) until IMPLEMENT lands the scaffold. The demo greeting pipeline is the only fully-realized example of the 10-phase flow — read it before building a new spec rather than starting from a blank page.

## Critical Never-Do

- Never write code before a failing test exists (`art-test-first`).
- Never push directly to main (`art-branch-as-state`, `art-review-gate`).
- Never create a separate repository (`art-repository-singleton`).
- Never commit `.env` (`art-secrets-hygiene`).
- Never cite an article by Roman numeral (`art-naming-tagging`).
