---
type: plan
phase: PLAN
spec: 2026-05-28-demo-greeting
decisions: [ADR-001]
created: "2026-05-28"
---

# Demo Greeting — Implementation Plan

Implements REQ-200 (per ADR-001), REQ-201, REQ-202.

This plan describes the *intent* and *ordering* of work. The runnable code, test bodies, and Dafny proof live in the IMPLEMENT phase (`src/`, `tests/`, `verification/`) — never in this PLAN document. Embedding code here would let an implementer skip TDD by reading the answer (violates `art-test-first`).

## Files

**Created:**
- `src/demo_greeting/__init__.py` — exposes `greet` for `from src.demo_greeting import greet`.
- `src/demo_greeting/greeting.py` — the single-function kernel module (per ADR-001).
- `verification/demo_greeting/greeting.dfy` — Dafny model proof of REQ-200's postcondition + invariant.
- `tests/demo_greeting/test_greeting.py` — REQ-201 (positive) + REQ-202 (precondition) tests.

## Task D1: Write the failing tests

Tests cover:
- REQ-201: `greet("World") == "Hello, World!"`
- REQ-202: `greet("")` raises `ValueError`

Run `python -m pytest tests/demo_greeting/ -q`. Confirm both tests **fail** (module missing). Do NOT write the implementation yet.

## Task D2: Implement greet

In `src/demo_greeting/greeting.py`, write the function so that ADR-001's decision (string concatenation) and REQ-200's contract hold:
- Precondition guard rejects empty string with `ValueError`.
- Postcondition: returns `"Hello, " + name + "!"`.
- Invariant: output length equals 8 + length of `name`.

Add `src/demo_greeting/__init__.py` to re-export `greet`.

Run pytest, confirm both tests **pass**.

## Task D3: Dafny proof

In `verification/demo_greeting/greeting.dfy`, write a `method Greet(name: string) returns (s: string)` whose `ensures` clauses encode REQ-200's three properties (length, prefix `"Hello, "`, suffix `'!'`). The body is a single line of string concatenation. Run `dafny verify` and confirm 0 errors.

This is a `[verifiable-model]` proof — it verifies the model, not the Python runtime directly. The two pytest cases (REQ-201/202) cover runtime; full runtime-contract extraction is deferred to v3.2 per v3.1 Open Question #1a.

## Task D4: Commit

Stage `tests/demo_greeting/`, `src/demo_greeting/`, `verification/demo_greeting/`. Commit message:
`feat(demo): greet() with tests + Dafny proof (REQ-200, REQ-201, REQ-202)`

After this commit, VALIDATE runs `bash scripts/run-quality-gates.sh` and expects `All quality gates passed` with pytest count incremented by 2 and Dafny verified count incremented by 2.
