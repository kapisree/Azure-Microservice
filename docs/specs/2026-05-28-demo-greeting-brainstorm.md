---
type: brainstorm
phase: BRAINSTORM
spec: 2026-05-28-demo-greeting
status: accepted
created: "2026-05-28"
---

# Brainstorm — Demo Greeting

## Goal
Smallest possible product that exercises every v3.1 phase end-to-end while remaining understandable in 15 minutes. A canonical structural template that other v3.1 projects can pattern-match against.

## Constraints
- Pure function (no I/O surface, no external deps) to minimize SECURITY surface.
- Single `[verifiable-model]` REQ to demonstrate the Dafny path without inventing complex domain logic.
- Python (single language, no archetype assumption).
- 0 expected SECURITY findings — to demonstrate that `REQ-113` "empty review allowed" works.

## Alternatives considered

- **Verified counter** (`Counter.increment()`): rejected — state-bearing logic complicates Dafny proof and obscures the "verified-greeting" intuition for first-time readers.
- **String reverser** (`reverse(s)`): rejected — the invariant ("output length equals input length") is less obvious to a casual reader, and reverse-of-reverse-is-identity is a subtle property to write as a frontmatter postcondition.
- **Greeting** (`greet(name)`): chosen — the postcondition reads aloud ("starts with `Hello, `, ends with `!`, contains name") so the Dafny invariants map 1:1 to a casual reader's intuition. No state, no I/O, no surface area.

## Decision
Build `greet(name: str) -> str` with:
- Precondition: `name != ""` (empty string raises `ValueError`)
- Postcondition: returns `"Hello, " + name + "!"`
- Invariant: length equals `len("Hello, ") + len(name) + 1`

Express as f-string in Python; model as string concatenation in Dafny. Single module, single function, zero dependencies.

## Hand-off
SPECIFY phase turns this brainstorm into `docs/specs/2026-05-28-demo-greeting-design.md` with REQ-200 tagged `[verifiable-model]`, plus REQ-201 (positive test) and REQ-202 (precondition test).
