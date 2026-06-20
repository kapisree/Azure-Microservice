---
name: architecture
description: ARCHITECTURE phase — produce ADRs, architecture overview, threat model from the spec.
argument-hint: <spec-slug>
---

You are entering the ARCHITECTURE phase for spec `$ARGUMENTS`.

Read `docs/specs/$ARGUMENTS-design.md` and `constitution.md` (articles `art-kernel-boundary` and `art-threat-driven-security`).

Produce in order:

1. One or more ADR files under `docs/adr/<NNN>-<topic>.md` with frontmatter `id`, `status: accepted`, `date`, `addresses: [REQ-NNN, ...]`. Body sections: Context, Decision, Consequences, Alternatives Considered.

2. `docs/architecture/$ARGUMENTS-overview.md` with frontmatter listing `kernel_modules` (each with `req_map` covering every `[verifiable]` REQ), `external_dependencies` (each with `justification`), `components`. Body: prose + Mermaid component diagram + Mermaid data-flow diagram.

3. `docs/architecture/$ARGUMENTS-threat-model.md` with frontmatter listing `assets` (each with CIA rating), `trust_boundaries`, `dataflow_elements`, `stride_per_element` (every element with `external: true` has ≥1 STRIDE letter). Body: narrative + data-flow diagram with element IDs matching the frontmatter.

When finished, run `/superpowers:brainstorming` only if alternatives are non-obvious — otherwise proceed to fresh-eyes review. Dispatch parallel reviewers including at least one customer persona (per project memory `feedback_customer-perspective-reviews.md`).

Then push and open PR per `.claude/rules/review-gate.md`.
