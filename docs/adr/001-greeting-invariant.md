---
id: ADR-001
status: accepted
date: 2026-05-28
addresses: [REQ-200]
---

# ADR-001: Use string concatenation for the verified greeting

## Context
REQ-200 needs a `greet(name)` function with formal invariants. We need a representation that lets Dafny prove the postcondition trivially.

## Decision
Implement as `f"Hello, {name}!"` in Python; model as string concatenation in Dafny. Keep the function pure (no I/O), inside the verified kernel.

## Consequences
- Trivially provable invariants.
- No external deps means no SECURITY supply-chain surface.
- Kernel boundary contains exactly one module: `src/demo_greeting/greeting.py`.

## Alternatives Considered
- Templating library (Jinja2): rejected — adds dependency, no invariant benefit.
- Format string in another language: rejected — would not exercise the Dafny path.
