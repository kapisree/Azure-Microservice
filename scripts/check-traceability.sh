#!/usr/bin/env bash
# Mechanical traceability checker (P3 of the 2026-06-09 review).
# Walks the chain the constitution promises is walkable
# (art-naming-tagging, art-specification-primacy, art-formal-verification):
#   - REQ IDs defined at most once across live (non-superseded) specs
#   - ADR ids unique; SEC ids unique
#   - every [verifiable]/[verifiable-model] REQ in a live, non-extended spec
#     has a Dafny proof carrying a matching "// Proves:" header
#   - no proof cites a REQ that no live spec defines
#     (verification/example.dfy is the documented placeholder — exempt)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
import glob, os, re, sys

def frontmatter(path):
    text = open(path).read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    fm = {}
    if m:
        for line in m.group(1).splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                fm[k.strip()] = v.strip()
    return fm, text

errors = []

# --- Spec inventory -------------------------------------------------------
live_specs, defined = {}, {}
for p in sorted(glob.glob("docs/specs/*.md")):
    fm, text = frontmatter(p)
    if fm.get("status") == "superseded":
        continue
    live_specs[p] = (fm, text)
    for req in set(re.findall(r"-\s+\*\*REQ-(\d{3}):?\*\*", text)):
        defined.setdefault(req, []).append(p)

for req, files in sorted(defined.items()):
    if len(set(files)) > 1:
        errors.append(f"REQ-{req} defined in multiple live specs: {sorted(set(files))}")

# --- Verifiable REQs need proofs -----------------------------------------
proves = {}
for p in sorted(glob.glob("verification/**/*.dfy", recursive=True)):
    if p == "verification/example.dfy":
        continue
    head = "".join(open(p).readlines()[:5])
    for req in re.findall(r"Proves: REQ-(\d{3})", head):
        proves.setdefault(req, []).append(p)

for spec, (fm, text) in live_specs.items():
    if fm.get("extended_by"):
        continue  # the extending spec is the live tip
    # Backtick-quoted `[verifiable]` is prose about the tag, not a tag.
    for req in re.findall(r"\*\*REQ-(\d{3}):?\*\*[^\n]*(?<!`)\[verifiable(?:-model)?\](?!`)", text):
        if req not in proves:
            errors.append(f"REQ-{req} ({spec}) is [verifiable*] but no proof carries 'Proves: REQ-{req}'")

# --- Dangling proof references --------------------------------------------
for req, files in sorted(proves.items()):
    if req not in defined:
        errors.append(f"proof(s) {files} prove REQ-{req}, which no live spec defines")

# --- ADR / SEC id uniqueness ----------------------------------------------
seen = {}
for p in sorted(glob.glob("docs/adr/*.md")):
    fm, _ = frontmatter(p)
    aid = fm.get("id", "")
    if aid:
        if aid in seen:
            errors.append(f"duplicate ADR id {aid}: {seen[aid]} and {p}")
        seen[aid] = p

sec_seen = {}
for p in sorted(glob.glob("docs/security/*-review.md")):
    for sec in re.findall(r"\bSEC-(\d{3})\b", open(p).read()):
        sec_seen.setdefault(sec, set()).add(p)
# (uniqueness across reviews is per-finding; only flag if same id in 2+ files)
for sec, files in sec_seen.items():
    if len(files) > 1:
        errors.append(f"SEC-{sec} appears in multiple reviews: {sorted(files)}")

if errors:
    print("FAIL: traceability check:")
    for e in errors:
        print("  -", e)
    sys.exit(1)

n_ver = sum(1 for s,(fm,t) in live_specs.items()
            for _ in re.findall(r"\[verifiable(?:-model)?\]", t))
print(f"PASS: traceability — {len(defined)} REQs across {len(live_specs)} live specs, "
      f"{len(proves)} proven, no duplicates or dangling references")
PY
