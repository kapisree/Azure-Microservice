---
type: spec
phase: SPEC
status: accepted
created: "2026-05-28"
approved_by: "apingali (PR #7 merge; lifecycle backfilled 2026-06-09)"
---

# Demo: Verified Greeting

## Overview

Smallest possible product that exercises every v3.1 phase. Produces a greeting function with a `[verifiable]` invariant: the greeting always starts with "Hello, " and ends with "!".

## Problem Statement

We need a canonical example showing how a v3.1 spec flows through ARCHITECTURE, PLAN, IMPLEMENT, VALIDATE, SECURITY, and RELEASE to produce a signed release artifact.

## User Personas

### Persona: Factory User
- **Role:** Engineer reading the v3.1 docs.
- **Goal:** See exactly what an end-to-end v3.1 cycle looks like.
- **Success looks like:** Walk the demo artifacts in the order produced and understand the whole pipeline.

## Objectives

1. Provide a runnable example small enough to read end-to-end in 15 minutes.
2. Exercise every v3.1 artifact type.
3. Produce a signed release tag with a verifiable dist artifact.

## Functional Requirements

### Must Have

- **REQ-200:** A function `greet(name: str) -> str` returns a greeting. [verifiable-model]
  - **Precondition:** `name` is a non-empty string of printable ASCII characters.
  - **Postcondition:** The returned string starts with `"Hello, "` and ends with `"!"`, and contains `name` between them.
  - **Invariant:** Length of the returned string equals `len("Hello, ") + len(name) + 1`.
  - **Verification scope:** Dafny verifies the model (`Greet` method postcondition matches); runtime is asserted by the two pytest cases (REQ-201, REQ-202). Runtime contracts (`art-formal-verification`) deferred to v3.2 per v3.1 Open Question #1a.
- **REQ-201:** A test verifies `greet("World") == "Hello, World!"`.
- **REQ-202:** A test verifies `greet("")` raises `ValueError` (precondition failure).

### Won't Have
- Internationalization, formatting options, anything else.

## Non-Functional Requirements
- Runs in CPython 3.10+. No external dependencies.
