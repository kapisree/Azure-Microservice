# SpecFlow Factory v3.1

A verified spec-to-code pipeline using SpecKit + Superpowers + Dafny. Every phase is a branch, every transition is a PR, critical paths get formal verification, and security + release are first-class phases with their own gates.

## Quick Start

1. Click **Use this template** on GitHub (or clone) to create a new repository — this repo *is* the template; there is no separate scaffold.
2. Run `bash scripts/init-project.sh` — prompts for project name and tech stack, creates all pipeline directories, writes `.stack`, and generates your per-stack quality-gate hook.
3. Edit `IDEA.md` with your product idea.
4. Run `/superpowers:brainstorming` to explore the design, then `/speckit.specify` to formalize the spec — tag critical requirements `[verifiable-model]` (Dafny proof of a contract model + tests of the implementation). The full `[verifiable]` tag additionally requires runtime-contract extraction, which lands in v3.2 — until then use the model tag (`art-formal-verification`).
5. Push `phase/spec` and open a PR to `main`. After review and merge, continue with `phase/arch`.

The repo ships with a complete worked example — the demo greeting pipeline (`docs/specs/2026-05-28-demo-greeting-*`) and its derived artifacts demonstrate all 10 phases. Use it as a structural template; see `CLAUDE.md` for the artifact map. Note: the demo's `.dfy` proofs make Dafny a hard requirement for `scripts/run-quality-gates.sh` — install Dafny, or delete `verification/demo_greeting/` along with the rest of the demo if you don't need the example.

## Workflow (10 phases)

```
main (integration branch)
├── phase/spec        → BRAINSTORM + SPECIFY            → PR
├── phase/arch        → ARCHITECTURE (ADRs, threat model)→ PR
├── phase/plan        → PLAN + TASKS + ANALYZE           → PR
├── impl/plan-N-*     → IMPLEMENT (TDD + Dafny)          → PR (one per plan)
├── phase/validate    → VALIDATE (quality gates)         → PR
├── phase/security    → SECURITY (review + disposition)  → PR
└── phase/release     → RELEASE (notes, tag, manifest)   → PR

Out-of-cycle: phase/retro-YYYY-MM-DD (retrospectives),
              impl/sec-<finding-id> (SECURITY back-edge)
```

Each phase uses specific tools (see `CLAUDE.md` for the exact commands) and merges via PR with:

- **Mechanical gates in CI** — `scripts/run-quality-gates.sh` (pytest + Dafny + governance tests) runs on every PR, plus Dafny verification and contract-alignment checks on `impl/*` and `phase/validate` branches.
- **Verifier review, run locally on your Claude subscription** — from a terminal *outside* any Claude Code session, run `scripts/run-verifier.sh <PR-number>`. It reviews the changed documents via `claude -p`, posts findings to the PR, and satisfies CI's "Verifier findings posted" attestation check. Add `--persona` for persona-based review. No API key is needed anywhere.
- **Human approval** — a reviewer enforces the verifier's verdict and merges.

## Key Files

| File | Purpose |
|------|---------|
| `IDEA.md` | Your product idea — the starting point |
| `CLAUDE.md` | The 10-phase pipeline table with exact tool invocations |
| `constitution.md` | The twelve non-negotiable articles — read first, cite by slug |
| `.claude/rules/` | Session-loaded operational rules (review gate, TDD) |
| `schemas/spec-template.md` | Spec template with `[verifiable]`/`[verifiable-model]` tag support |
| `verification/README.md` | Dafny installation, proof patterns, contract extraction |
| `docs/specs/2026-05-28-demo-greeting-design.md` | Canonical worked example (all 10 phases) |

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/init-project.sh` | One-time project setup (dirs, `.stack`, per-stack hook) |
| `scripts/run-quality-gates.sh` | VALIDATE gate: pytest + Dafny + governance tests + stack hook |
| `scripts/run-verifier.sh` | Verifier review via `claude -p` (run outside a Claude session) |
| `scripts/analyze-adr-plan-linkage.sh` | ANALYZE gate: ADR → plan traceability check |
| `scripts/configure-repo.sh` | GitHub branch protection setup |
| `scripts/render-dashboard.sh` | Generate the pipeline dashboard |
| `scripts/render-doc.sh` / `verify-doc.sh` | Doc rendering and structural checks |
| `scripts/cleanup-worktrees.sh` | Clean up stale worktrees |

## Formal Verification (Dafny)

Tag critical requirements `[verifiable-model]` (or, from v3.2, `[verifiable]`) in your spec. During IMPLEMENT, write Dafny proofs for those requirements in `verification/`.

```bash
# Verify all proofs (recursive — matches what CI and the gates run)
dafny verify $(find verification -name '*.dfy')

# See the verification guide
cat verification/README.md
```

## Requirements

- Git, GitHub CLI (`gh`)
- Python 3.12+ (template tooling — independent of your product stack); `pip install -r scripts/requirements.txt`
- Claude Code with a subscription (the verifier runs on it — no API key needed)
  - [SpecKit](https://github.com/github/spec-kit) and [Superpowers](https://github.com/obra/superpowers) installed as Claude Code plugins
- Dafny — required while any `.dfy` files exist in `verification/` (the shipped demo includes proofs; install Dafny or remove the demo)
