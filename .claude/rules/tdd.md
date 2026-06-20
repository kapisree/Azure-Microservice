# TDD Enforcement

**This rule loads at every session start.** Operational rule for `art-test-first`.

Before writing ANY implementation code:
1. A failing test for that code MUST already exist.
2. Run the test and confirm it FAILS (e.g., `pytest <test_file> -x`, or
   `bash tests/governance/<test>.sh` for governance behavior).
3. Only then write the minimum implementation to make it pass.
4. Refactor. Confirm it still passes.

If you find yourself writing implementation code without a corresponding
failing test, STOP. Write the test first. This is non-negotiable.

Scope notes for this factory:
- "Implementation code" includes shell scripts in `scripts/` and CI workflow
  logic — governance tests in `tests/governance/` are their test layer.
- `[verifiable-model]` requirements additionally need a Dafny proof in
  `verification/` (`art-formal-verification`); the proof complements, never
  replaces, the failing test.
- The verifier flags phases that show implementation commits with no earlier
  or same-commit test.
