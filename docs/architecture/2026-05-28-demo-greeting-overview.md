---
spec: 2026-05-28-demo-greeting
kernel_modules:
  - path: src/demo_greeting/greeting.py
    req_map: [REQ-200]
external_dependencies: []
components: [greeting]
---

# Demo Greeting — Architecture Overview

A single pure function. No external dependencies. The kernel boundary is the function itself; everything outside (the test runner) is unverified.

```mermaid
flowchart LR
  Caller([caller]) --> Greet[greet name]
  Greet -->|"Hello, NAME!"| Caller
```

## Data flow
- `name: str` enters the function.
- Validation: `name != ""` (precondition).
- Output: literal `"Hello, "` + `name` + `"!"`.

## Verified kernel boundary
`src/demo_greeting/greeting.py`. Tests (`tests/demo_greeting/test_greeting.py`) live outside the kernel.
