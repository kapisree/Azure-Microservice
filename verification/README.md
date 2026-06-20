# Formal Verification with Dafny

This directory contains Dafny proof files (.dfy) that formally verify the contract models for critical requirements tagged `[verifiable]` in the specification.

## What This Proves

Dafny proofs verify that a **contract model** is internally consistent and total — meaning the preconditions, postconditions, and invariants hold for all possible inputs. This is NOT proof that the production code is correct. It is proof that the contract the code implements is sound.

Three layers work together:
1. **Dafny proof** (this directory) — proves the contract model is correct for all inputs
2. **Runtime contracts** (`src/contracts/`) — enforce proven contracts at the boundary
3. **Tests** (`tests/`) — verify the implementation behaves correctly for specific cases

## Installing Dafny

### macOS
```bash
brew install dafny
```

### Ubuntu
```bash
wget -q https://github.com/dafny-lang/dafny/releases/download/v4.9.1/dafny-4.9.1-x64-ubuntu-20.04.zip
unzip -q dafny-4.9.1-*.zip -d /opt/dafny
export PATH="/opt/dafny/dafny:$PATH"
```

### Verify installation
```bash
dafny --version
```

## Writing Your First Proof

See `example.dfy` in this directory for a complete, working example.

### The Pattern

1. **Define predicates** for your preconditions (what must be true before)
2. **Define datatypes** for your result types
3. **Declare external dependencies** with `requires`/`ensures` contracts but no body
4. **Write your method** with `ensures` clauses that state the postconditions
5. **Implement the body** — Dafny checks that the body satisfies the `ensures` clauses

### Running Verification

```bash
# Verify a single file
dafny verify verification/example.dfy

# Verify all proofs
dafny verify verification/*.dfy
```

### Interpreting Failures

Common Dafny error messages and what they mean:

- **"postcondition might not hold"** — Your method body doesn't guarantee the `ensures` clause for all paths. Check: is there a code path where the postcondition could be false?
- **"precondition for call might not hold"** — You're calling a method without satisfying its `requires` clause. Check: did you validate the input before the call?
- **"decreases expression must be non-negative"** — A loop or recursive call might not terminate. Add a `decreases` clause with a value that decreases toward zero.
- **"assertion might not hold"** — An explicit `assert` in your code isn't provably true. You may need a helper lemma.

### Advanced Patterns

For nontrivial proofs, you'll need:
- **Lemmas** — helper proofs that establish intermediate facts: `lemma SomeProperty(x: int) ensures x * x >= 0 { }`
- **Ghost variables** — variables that exist only for proof purposes, not in the compiled code
- **Decreases clauses** — termination metrics for loops and recursion: `while i < n decreases n - i`
- **Assertions** — intermediate proof steps that help Dafny: `assert ValidToken(token);`

## Extracting Runtime Contracts

After a Dafny proof verifies successfully:

1. Read the `requires` clauses → these become precondition checks
2. Read the `ensures` clauses → these become postcondition assertions
3. Translate to the target language:
   - **Python:** decorators with `beartype`, `pydantic` validators, or custom wrappers
   - **TypeScript:** `zod` schemas, branded types, or assertion functions
4. Place in `src/contracts/<module>.py` or `src/contracts/<module>.ts`
5. Add header: `# Extracted from: verification/<module>.dfy (Proves: REQ-NNN)`
6. Import the contract in the implementation module

## File Convention

Each `.dfy` file must have a `Proves:` header comment:
```dafny
// verification/<module>.dfy
// Proves: REQ-001, REQ-003
```

Each contract file must have an `Extracted from:` header:
```python
# src/contracts/<module>.py
# Extracted from: verification/<module>.dfy (Proves: REQ-001, REQ-003)
```

CI checks that these headers are consistent.
