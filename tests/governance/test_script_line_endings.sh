#!/usr/bin/env bash
# Governance test: scripts/*.sh and tests/governance/*.sh must have LF line
# endings. A script with CRLF line endings breaks its own #!/usr/bin/env bash
# shebang under WSL/Linux/Mac ("/usr/bin/env: 'bash\r': No such file or
# directory") whenever it's invoked directly rather than via `bash <script>`.
# scripts/run-verifier.sh is documented (CLAUDE.md, review-gate.md) to run
# as `scripts/run-verifier.sh <PR>` — direct shebang execution — so this
# class of bug breaks it for any non-Windows-shell contributor even though
# run-quality-gates.sh's `bash "$t"` invocation of governance tests masks
# the same defect there. Guards against core.autocrlf=true (or any future
# CRLF reintroduction) silently breaking this.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FAIL=0
for f in scripts/*.sh tests/governance/*.sh; do
  [[ -f "$f" ]] || continue
  if grep -Uq $'\r' "$f"; then
    echo "FAIL: $f has CRLF line endings (breaks #!/usr/bin/env bash under WSL/Linux/Mac)"
    FAIL=1
  fi
done

if [[ $FAIL -ne 0 ]]; then
  echo "test_script_line_endings: FAILED"
  exit 1
fi
echo "test_script_line_endings: all scripts/*.sh and tests/governance/*.sh have LF line endings"
