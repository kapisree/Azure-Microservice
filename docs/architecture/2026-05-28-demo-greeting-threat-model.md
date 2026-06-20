---
spec: 2026-05-28-demo-greeting
assets:
  - name: greeting-output
    cia: {c: L, i: M, a: L}
trust_boundaries:
  - name: function-boundary
    between: [caller, greet]
dataflow_elements:
  - id: dfe-1
    name: name-input
    external: true
stride_per_element:
  dfe-1: [T]
---

# Demo Greeting — Threat Model

## Narrative
The only external input is the `name` parameter. The function performs no I/O, opens no sockets, reads no files. Trust boundary is between the caller and the function body.

## STRIDE coverage
- `dfe-1` (name-input): T (tampering). A caller may pass a maliciously-crafted string. Mitigation: precondition rejects empty strings; output is purely deterministic so no injection sink exists.

## Mitigations
- Precondition validates non-empty.
- Pure function — no eval, no system calls, no logging that could re-serialize attacker input unsafely.

```mermaid
flowchart LR
  subgraph external [external]
    Caller([caller])
  end
  subgraph kernel [kernel]
    Greet[greet]
  end
  Caller -- "dfe-1" --> Greet
```
