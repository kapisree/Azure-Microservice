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
