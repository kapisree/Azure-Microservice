---
type: spec
phase: SPEC
status: draft          # draft | accepted | superseded — flip to accepted when the spec PR merges
created: ""
approved_by: ""        # reviewer handle + PR, set at merge
supersedes: ""         # filename of the spec this replaces, if any
extends: ""            # filename of the spec this builds on, if any
superseded_by: ""      # set on THIS spec when a later spec replaces it
extended_by: ""        # set on THIS spec when a later spec extends it (mirror of extends)
---

# [Project/Feature Name] Specification

## Overview
[One paragraph describing what this specification covers.]

### Scope
[Which personas are in scope and which are explicitly out. One line per persona:
"In: <persona> — <what they get>. Out: <persona> — <why not this version>."]

## Problem Statement
[What problem does this solve? Why does it need solving now?]

## User Personas

### Persona: <Name>
- **Role:** <who they are>
- **Goal:** <what they're trying to accomplish>
- **Context:** <how they use the product, constraints, tech comfort>
- **Success looks like:** <observable outcome from their perspective>

## Objectives
[Observable outcomes — what changes in the world when this is built?]

## Functional Requirements

### Must Have
- **REQ-XXX:** [verifiable-model] Requirement description
  - **Precondition:** <what must be true before this executes>
  - **Postcondition:** <what must be true after this executes>
  - **Invariant:** <what must always be true>
  - **Verification scope:** <what the Dafny proof covers (the model) vs what tests cover (the implementation)>
- **REQ-XXX:** Requirement description (no verification needed — TDD only)

> Replace `REQ-XXX` with real three-digit IDs. IDs are globally unique across
> ALL specs in the repo (`art-naming-tagging`) — check existing specs and
> continue the sequence; never reuse or restart numbering. Every clause of a
> `[verifiable*]` REQ's contract (each pre/postcondition and invariant) must
> map to at least one named acceptance test.

### Should Have
- **REQ-NNN:** [Requirement description]

### Won't Have (this version)
- [Explicit out-of-scope items]

## Non-Functional Requirements
- **Performance:** [Targets]
- **Security:** [Requirements]
- **Scalability:** [Expectations]
- **Compliance:** [Regulations]

## Verification Identification

Two tags (`art-formal-verification`): `[verifiable]` = Dafny proof + runtime
contract in `src/contracts/` (contract extraction lands in v3.2 — until then
use the model tag); `[verifiable-model]` = Dafny proof of a contract model +
tests of the real implementation.

Tag a requirement when it involves:
- Authentication/authorization logic
- Payment/financial calculations
- Data integrity constraints
- State machine transitions
- Cryptographic operations
- Rate limiting / quota enforcement

Do NOT tag: UI rendering, logging, third-party API integrations, performance characteristics.

Mixed cases: tag the domain logic contract, model external dependencies with assumed contracts.

## Success Metrics
[Measurable outcomes per objective]

## Open Questions
[Unresolved items needing human input]

## Assumptions
[Assumptions the spec relies on — flag for verification]

## Risks
[Known risks with severity and mitigation]
