#!/usr/bin/env bash
# Reviewer helper: mechanically verify a release PR against
# art-release-readiness. Usage: scripts/verify-release.sh <version>
# (e.g. scripts/verify-release.sh 0.0.1-demo)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${1:?usage: verify-release.sh <version>}"
FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
pass() { echo "ok:   $1"; }

# 1. Three release docs
for d in notes migration known-limitations; do
  f="docs/releases/${VERSION}-${d}.md"
  [[ -f "$f" ]] && pass "$f exists" || fail "$f missing"
done

# 2. Tag exists; signed, or annotated with recorded fallback
if git rev-parse -q --verify "refs/tags/v${VERSION}" >/dev/null; then
  if git tag -v "v${VERSION}" >/dev/null 2>&1; then
    pass "tag v${VERSION} exists and signature verifies"
  elif [[ "$(git cat-file -t "v${VERSION}")" == "tag" ]] \
       && grep -qi 'annotated\|gpg' "docs/releases/${VERSION}-known-limitations.md" 2>/dev/null; then
    pass "tag v${VERSION} annotated with GPG fallback recorded in known-limitations"
  else
    fail "tag v${VERSION} not signed and no fallback recorded (art-release-readiness)"
  fi
else
  fail "tag v${VERSION} does not exist"
fi

# 3. Manifest transcription in notes
if grep -qE '[0-9a-f]{64}' "docs/releases/${VERSION}-notes.md" 2>/dev/null; then
  pass "release notes transcribe sha256 checksums"
else
  fail "release notes do not transcribe the manifest (filename + sha256 + size)"
fi

# 4. If dist/ exists locally, verify checksums against the manifest
if [[ -f dist/manifest.json ]]; then
  if python3 - <<'PY'
import hashlib, json, os, sys
m = json.load(open("dist/manifest.json"))
entries = m if isinstance(m, list) else m.get("artifacts", m.get("files", []))
bad = 0
for e in entries:
    name, want = e.get("file") or e.get("filename") or e.get("name"), e.get("sha256")
    p = os.path.join("dist", name)
    if not os.path.exists(p):
        print(f"  missing: {p}"); bad += 1; continue
    got = hashlib.sha256(open(p, "rb").read()).hexdigest()
    if got != want:
        print(f"  checksum mismatch: {name}"); bad += 1
sys.exit(1 if bad else 0)
PY
  then pass "dist/manifest.json checksums verify"; else fail "dist checksum mismatch"; fi
else
  echo "note: dist/ not present locally (gitignored) — checksums auditable from the notes transcription"
fi

# 5. Every accepted/deferred SEC-NNN in the disposition appears in known-limitations
DISP="docs/security/${VERSION}-disposition.md"
KL="docs/releases/${VERSION}-known-limitations.md"
if [[ -f "$DISP" ]]; then
  MISSING=0
  while IFS= read -r sec; do
    grep -q "$sec" "$KL" 2>/dev/null || { fail "$sec accepted/deferred but absent from known-limitations"; MISSING=1; }
  done < <(grep -B5 -E 'status: (accepted|deferred)' "$DISP" 2>/dev/null | grep -oE 'SEC-[0-9]{3}' | sort -u)
  [[ $MISSING -eq 0 ]] && pass "known-limitations covers every accepted/deferred SEC-NNN"
fi

# 6. Quality gates
if bash scripts/run-quality-gates.sh >/dev/null 2>&1; then
  pass "quality gates green"
else
  fail "quality gates failing"
fi

if [[ $FAIL -ne 0 ]]; then
  echo "verify-release: FAILED for v${VERSION}"
  exit 1
fi
echo "verify-release: v${VERSION} satisfies the mechanical art-release-readiness gate"
