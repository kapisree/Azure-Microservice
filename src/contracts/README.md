# Runtime Contracts

This directory contains runtime contracts extracted from Dafny proofs in `verification/`.

Each contract file enforces the preconditions and postconditions that Dafny proved correct for the contract model. They are the bridge between the verified model and the production code.

## Convention

Each file must have an `Extracted from:` header:
```python
# Extracted from: verification/<module>.dfy (Proves: REQ-NNN)
```

## See Also

- `verification/README.md` — how to write proofs and extract contracts
- `verification/example.dfy` — example proof
