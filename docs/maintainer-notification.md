# Security Advisory Notification for supergateway

Dear @Nedomas and the supergateway team,

I have discovered two high-severity security vulnerabilities in supergateway and would like to coordinate disclosure with you. Full research, including working exploits, captured proof, and a validated patch, is available at:

https://github.com/Teycir/supergateway-security-research

## Summary of Findings

| ID | Finding | Mode | Severity | CWE |
|---|---|---|---|---|
| SGW-2026-001 | Unauthenticated remote DoS via prototype-chain `sessionId` | stdio → SSE | **High 7.5** | CWE-248 / CWE-754 |
| SGW-2026-002 | Cross-Site WebSocket Hijacking (no `Origin` check) | stdio → WS | **High 8.1** | CWE-1385 |

## SGW-2026-001: Unauthenticated Remote DoS

**Impact:** An unauthenticated `POST /message?sessionId=toString` (or any prototype chain key like `__proto__`, `constructor`, `hasOwnProperty`, `valueOf`) terminates the entire gateway process and all attached MCP sessions. No active session or credentials required.

**Root cause:** Sessions stored in a plain object (`{}`) without ownership checks. Prototype chain keys return truthy non-session values, causing `TypeError` on `session.transport.handlePostMessage(...)` in an async Express handler. Node.js exits on unhandled rejection.

**Verified:** 15/15 crashes across five payloads, including non-loopback interface and raw TCP reproduction.

**Fix:** Replace plain object with `Map` and validate ownership (patch included in research repo).

## SGW-2026-002: Cross-Site WebSocket Hijacking

**Impact:** Any web page can connect to `ws://127.0.0.1:<port>/ws` from any origin, drive the local MCP server, and invoke tools (filesystem, shell, APIs) with the victim's privileges. Server accepts `Origin: null` and any arbitrary origin.

**Root cause:** WebSocket upgrade handler never validates `req.headers.origin`, and authentication is optional/not enabled by default.

**Verified:** 12/12 exfiltrations across four origins, including real Chromium browser proof.

**Fix:** Validate `Origin` against allowlist during upgrade, require API key for upgrades, bind loopback by default.

## Research Repository Contents

- **Advisories:** Full technical details with CVE-ready text
- **PoCs:** Exploits, harnesses, verification scripts (36-check sweep, all passing)
- **Evidence:** Captured logs, screenshots, source proof, checksums
- **Patch:** Validated fix for SGW-2026-001
- **CVE Request:** Prepared CVE 5.1 request templates (JSON and markdown)

## Coordination Request

I have attempted to submit GHSA advisories, but my token only has read access to `supercorp-ai/supergateway`, so they were published under my fork (`Teycir/supergateway`):

- GHSA-96g7-x7h4-cr9v (SGW-2026-001)
- GHSA-mw77-x7vj-mfcc (SGW-2026-002)

**I request that you:**

1. Review the research repository and validate the findings
2. Submit new GHSA advisories under `supercorp-ai/supergateway` using the prepared CVE request text in `docs/cve-request.md` and `cve/`
3. Coordinate CVE assignment through GitHub CNA (or MITRE if preferred)
4. Determine a coordinated disclosure timeline

The fork advisories cannot be withdrawn (published via API), but new advisories under the correct repository will be the canonical references.

## Prior Art

Upstream PR #178 contains prior work on the session management fix shape, which my patch builds upon.

## Timeline

- 2026-11-17: Findings discovered and verified
- 2026-11-17: 36/36 verification sweep completed
- 2026-11-17: Patch validated
- 2026-11-17: Research repository assembled
- 2026-11-17: GHSA advisories submitted (incorrect repo due to permissions)
- **Pending:** Vendor notification / CVE assignment / coordinated disclosure

## Contact

I am available to discuss these findings, provide additional context, or assist with patch integration. Please let me know your preferred coordination process and timeline.

Best regards,
Teycir
