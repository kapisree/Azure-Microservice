# Security Severity Rubric

Referenced by `art-threat-driven-security` and REQ-114. This file is the
canonical location for the disposition caps and the scoring worked example.

```yaml
medium_cap: 5        # max accepted|deferred mediums per release (override here, with PR review)
```

## Severity bands (CVSS v4.0 base score)

| Severity | CVSS v4.0 Base |
|---|---|
| critical | 9.0–10.0 |
| high | 7.0–8.9 |
| medium | 4.0–6.9 |
| low | 0.1–3.9 |

Rules (see `art-threat-driven-security` for the full text):
- Critical/high must reach `status: fixed` — never accepted/deferred.
- Accepted/deferred mediums are capped at `medium_cap` per release and need `owner:` + `expiry:`.
- Lows need no expiry and don't count toward the cap.
- No CWE→CVSS auto-mapping: CWE is structural, CVSS is contextual.
- Solo teams: author scores provisionally; the next available second reviewer confirms or downgrades, recorded in the disposition's `rationale:`.
- `status: superseded` (added 2026-06-23, retro `2026-06-22-sec-006-process-gap` proposal #1): use when a later finding, under a new ID, re-describes and closes the gap an older finding named. The superseded finding records `superseded_by: <new-id>`, carries no `expiry:`, and is excluded from the medium cap — it is traceability, not an open risk. Example: `docs/security/0.2.0-disposition.md`'s SEC-001 entry, superseded by SEC-007 once authentication closed the unauthenticated-access gap SEC-001 originally described. **Guard for critical/high originals (`art-threat-driven-security`):** `superseded` is not a substitute for `fixed` on a critical/high. It's permitted only if the `superseded_by:` finding is itself `status: fixed`, or the disposition's `rationale:` documents that the underlying risk (not just the wording) is closed and a second reviewer independently confirms the residual's lower severity — otherwise the original stays `open` and blocks RELEASE.

## Carrying findings forward without re-minting IDs

`scripts/check-traceability.sh` enforces that each `SEC-NNN` token appears
in exactly one `docs/security/*-review.md` file. A new `<version>-review.md`
that restates a carried-forward finding's full text under its original ID
will fail that check. Instead:

- Keep the finding's full `id:`/severity/text in the review document that
  originated it; never repeat the literal `SEC-NNN` token in a later
  `<version>-review.md`.
- In the new review document, describe carried-forward findings by topic
  or affected file only (e.g. "the mutable Docker tag finding, unchanged"),
  with a prose pointer to the originating review file.
- The new `<version>-disposition.md` document — which `check-traceability.sh`
  does not scan — is where the literal ID, current status, owner, and
  expiry are restated for gate accounting.

## Worked example

Finding: the release hook (`scripts/release-<stack>.sh`) makes an outbound
network call introduced by a malicious dependency update.

CVSS v4.0 vector reasoning, metric by metric:

| Metric | Value | Why |
|---|---|---|
| Attack Vector | Network (AV:N) | exfiltration target is remote |
| Attack Complexity | Low (AC:L) | no special conditions once the hook runs |
| Attack Requirements | Present (AT:P) | requires a poisoned dependency to land first |
| Privileges Required | None (PR:N) | hook runs with the developer's ambient credentials |
| User Interaction | Passive (UI:P) | a maintainer must run the release |
| Vulnerable system C/I/A | High/High/None | artifacts + signing context exposed/modifiable |

Score ≈ 7.1 → **high** → must be `fixed` before RELEASE (back-edge:
`impl/sec-<finding-id>`), regardless of how inconvenient that is.

Counter-example: the same outbound call in the *dashboard renderer* (no
secrets in scope, output is gitignored HTML) scores ≈ 4.x → **medium** →
eligible for `accepted` with owner + expiry, within the cap.

The point of the pair: identical CWE (CWE-829), two different severities —
context decides, which is why there is no CWE→CVSS auto-mapping.
