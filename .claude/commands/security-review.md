---
name: security-review
description: SECURITY phase — produce severity-rated review and per-finding disposition.
argument-hint: <version>
---

You are entering the SECURITY phase for release `v$ARGUMENTS`.

Read `constitution.md` article `art-threat-driven-security` (severity rubric is CVSS v4.0 base score). Read the threat model: `docs/architecture/<spec-slug>-threat-model.md` for the spec that drove this release.

Produce in order:

1. `docs/security/$ARGUMENTS-review.md`. Each finding is a markdown subsection with YAML frontmatter:
   ```yaml
   ---
   id: SEC-NNN
   severity: critical | high | medium | low   # by CVSS v4.0 base
   cite: [<threat-id>, <CWE-NNN>, <OWASP-ref>]   # ≥1
   affects: [<path>:<line>, ...]
   ---
   ```
   Body: ≤200 words on the finding, evidence, suggested remediation.

2. `docs/security/$ARGUMENTS-disposition.md`. Per finding YAML frontmatter:
   ```yaml
   ---
   id: SEC-NNN
   status: open | fixed | accepted | deferred
   owner: <github-handle>
   expiry: YYYY-MM-DD   # required if accepted or deferred
   rationale: "..."     # ≥10 chars; reclassification requires a second reviewer named here
   ---
   ```

Gate:
- Zero `severity: critical, status: open`.
- Zero `severity: high, status: open`.
- Mediums with `accepted | deferred` capped at 5 (default; override in `docs/security/RUBRIC.md`).

If any critical or high finding requires code change: open `impl/sec-<finding-id>` from main, fix with TDD, merge, re-run VALIDATE, then resume here with `status: fixed`.

Push and open PR per `.claude/rules/review-gate.md`.
