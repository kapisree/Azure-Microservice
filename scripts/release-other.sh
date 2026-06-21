#!/usr/bin/env bash
# Per-stack RELEASE hook for the .NET/C# stack (.stack = "other").
# Implements REQ-110 / art-release-readiness's per-stack hook contract.
#
# Pure local packaging, no outbound network calls: archives the source
# the deployed container image is built from, plus the infra templates
# and CI workflow that provision/deploy it. The container image itself
# is built and pushed separately by .github/workflows/claims-api.yml.
set -euo pipefail

: "${VERSION:?VERSION env var required}"
: "${DIST_DIR:?DIST_DIR env var required}"
mkdir -p "$DIST_DIR"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

tar czf "$DIST_DIR/claims-status-api-$VERSION.tar.gz" \
  src/ClaimsApi \
  src/contracts \
  tests/ClaimsApi.Tests \
  infra \
  .github/workflows/claims-api.yml

python3 - <<'PY'
import hashlib, json, os
dist = os.environ["DIST_DIR"]
version = os.environ["VERSION"]
entries = []
for name in sorted(os.listdir(dist)):
    path = os.path.join(dist, name)
    if not os.path.isfile(path) or name == "manifest.json":
        continue
    with open(path, "rb") as f:
        h = hashlib.sha256(f.read()).hexdigest()
    entries.append({"filename": name, "sha256": h, "size": os.path.getsize(path)})
with open(os.path.join(dist, "manifest.json"), "w") as f:
    json.dump({"version": version, "artifacts": entries}, f, indent=2)
print(f"Wrote manifest with {len(entries)} artifact(s)")
PY
