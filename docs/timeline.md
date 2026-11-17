# Timeline (UTC)

| Date/time | Event | Artifact |
|---|---|---|
| 2026-11-17T20:22:25Z | Engagement report finalized: findings, PoCs, evidence | `docs/verification.md` |
| 2026-11-17T20:30–20:31Z | Hardened sweep executed: 36 checks, 5 payloads, 4 origins, API-key controls, non-loopback | `evidence/verification/summary_203133.log` |
| 2026-11-17T20:32:21Z | Proposed fix applied, built, tested, source restored; vulnerable build re-confirmed | `evidence/fix_validation.log`, `evidence/post_restore_crash.log` |
| 2026-11-17T20:33Z | Evidence re-hashed; report marked re-verified | engagement report |
| 2026-11-17T20:39Z | Public research repository assembled (this package) | `SHA256SUMS` |
| pending | Vendor notification via upstream security policy | `docs/cve-request.md` |
| pending | CVE request submitted to CNA of record | `cve/request-SGW-2026-00{1,2}.json` |
| pending | Advisory publication after coordination | `advisories/` |

Notes:

- The vulnerable tree was never left patched: `git checkout -- src` plus rebuild was executed after fix validation.
- No claim in this package depends on a failed exploratory request; the deterministic harness is the basis for all crash results.
