# Supergateway security research — 2026

Two independently reproducible vulnerabilities in [supergateway](https://github.com/supercorp-ai/supergateway), the MCP stdio↔network bridge, with working exploits, captured proof, and a validated patch.

| ID | Finding | Mode | Severity | CWE | Status |
|---|---|---|---|---|---|
| [SGW-2026-001](advisories/SGW-2026-001.md) | Unauthenticated remote DoS via prototype-chain `sessionId` | stdio → SSE | **High 7.5** | CWE-248 / CWE-754 | CVE requested |
| [SGW-2026-002](advisories/SGW-2026-002.md) | Cross-Site WebSocket Hijacking (no `Origin` check) | stdio → WS | **High 8.1** | CWE-1385 | CVE requested |
| [RT-03](docs/analysis.md#rt-03-information-disclosure-in-logs) | Full JSON-RPC requests logged at `info` (credentials, tool arguments) | SSE | Medium 6.4 | CWE-532 | Included with 001 |

Verified against **supergateway 4.2.2**, commit [`5ad19d3`](https://github.com/supercorp-ai/supergateway/tree/5ad19d39c033fde33f18c2edefa996771980aafe) (tag `v4.2.2-4-g5ad19d3`), Node.js 22.21.0, Linux.

## Reproduce

```bash
git clone <THIS-REPO> supergateway-security-research
cd supergateway-security-research

./scripts/bootstrap.sh          # clone supergateway @ 5ad19d3, npm ci, build (vulnerable)
./pocs/verify_all.sh 3          # 36 checks: both vulns, payloads, origins, controls
./pocs/verify_fix.sh            # apply patch, rebuild, prove fix, restore tree
```

`./scripts/reproduce.sh` does all three. Expect `36 passed, 0 failed` and `FIX VALIDATED`.

## What is proven

- **SGW-2026-001** — five prototype keys (`toString`, `__proto__`, `constructor`, `hasOwnProperty`, `valueOf`) kill the gateway in **15/15** runs; no session and no credentials required; reproducible over a non-loopback interface; raw TCP (`nc`) reproduction included. Patched build returns `503`, stays alive, and still serves legitimate sessions.
- **SGW-2026-002** — a malicious page exfiltrates a local file through the victim's gateway from **four origins × 3 runs** (12/12), including a real Chromium proof (`evidence/cswsh_browser.png`). `--apiKey` refuses unauthenticated upgrades.
- **RT-03** — a unique secret marker placed in `_meta.password` appears verbatim in the gateway's `info` log (3/3).

## Repository layout

```
advisories/     advisory text, CVE-ready
cve/            CVE 5.1 request templates (JSON)
docs/           root-cause analysis, remediation, verification, timeline, CVE text
pocs/           exploits, harnesses, receiver, verification scripts
patches/        proposed fix (applies to 5ad19d3)
evidence/       captured logs, screenshot, source proof, checksums
scripts/        bootstrap, reproduce, checksums
```

## Scope and safety

All work was performed in an isolated lab against local instances. The PoCs bind to loopback by default and require an explicit target URL otherwise. Use only against systems you own or are authorised to test. Logs in `evidence/` contain lab paths and test values (test API key `K3yTest`, canary `SGW-CANARY-…`); none are production secrets.

## Plain-language explanations

See `docs/vulnerabilities-simple.md` for simple, non-technical descriptions of both bugs and their attack paths.

## GHSA submission

Both advisories were submitted and published via the GitHub Security Advisory API (token `Teycir`) on 2026-11-17. Because the token only has read access to upstream `supercorp-ai/supergateway`, the advisories were published under the `Teycir/supergateway` fork:

| Research ID | GHSA ID | Finding | Published |
|-------------|---------|---------|-----------|
| SGW-2026-001 | GHSA-96g7-x7h4-cr9v | Unauthenticated remote DoS via prototype-chain `sessionId` | 2026-11-17T21:04:55Z |
| SGW-2026-002 | GHSA-mw77-x7vj-mfcc | Cross-Site WebSocket Hijacking via missing `Origin` validation | 2026-11-17T21:05:13Z |

**Status:** Published under fork (incorrect repository). Published advisories cannot be withdrawn via API. The upstream maintainers have been requested to submit canonical advisories under `supercorp-ai/supergateway` using the prepared CVE request text in `docs/cve-request.md` and `cve/`. See `docs/maintainer-notification.md` for the full notification message.

## Disclosure

- 2026-11-17 — findings discovered and verified; report and PoCs produced.
- 2026-11-17 — re-verified 36/36; patch validated; this package assembled.
- 2026-11-17 — GHSA advisories submitted and published (see table above).
- 2026-11-17 — **Vendor contacted via public issue #378**: https://github.com/supercorp-ai/supergateway/issues/378
- 2026-11-17 — Research repository made public: https://github.com/Teycir/supergateway-security-research
- 2026-11-17 — **VulDB submissions submitted** (both vulnerabilities, IDs pending processing)
- 2026-11-17 — **VulnCheck submissions submitted** (both vulnerabilities: SGW-2026-001: 8d6ec57c-cd0e-4ea1-9727-4608822f3442, SGW-2026-002: 844df8d2-8b17-4072-8af1-ea68aab893fe)
- **CVE request text and JSON are prepared in `docs/cve-request.md` and `cve/`. Awaiting upstream response for canonical GHSA submission and CVE assignment.**

Contact: Teycir (@Teycir) via GitHub issues or the upstream issue #378. The maintainers' own policy is in the upstream `SECURITY.md`.

## Credits

Research, exploit development, and report: Teycir (@Teycir). Reported with coordinator assistance as applicable.

## License

MIT — see [LICENSE](LICENSE). The license covers this repository's original content; upstream supergateway remains under its own license.
