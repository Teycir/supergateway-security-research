# VulDB Submission - SGW-2026-001

**Submitter:** Teycir (@Teycir)
**Date:** 2026-11-17
**Research Repository:** https://github.com/Teycir/supergateway-security-research

## Vulnerability Information

**Title:** Unauthenticated Remote Denial of Service via Prototype-Chain Session Identifier in supergateway

**Vendor:** supercorp-ai
**Product:** supergateway (npm package)
**Affected Versions:** <= 4.2.2 (verified on commit 5ad19d3)
**Vulnerability Class:** Denial of Service (CWE-248, CWE-754)
**Severity:** High (CVSS 3.1: 7.5)

## Description

In stdio→SSE mode, the supergateway gateway stores sessions in a plain JavaScript object and looks up sessions by a client-supplied `sessionId` query parameter without ownership validation. Keys inherited from `Object.prototype` (such as `toString`, `constructor`, `__proto__`, `hasOwnProperty`, `valueOf`) return truthy non-session values. The code then attempts to call `session.transport.handlePostMessage(...)` inside an async Express route handler, which throws a `TypeError`. With no unhandled rejection handler, Node.js terminates the process.

An unauthenticated `POST /message?sessionId=toString` (or any prototype chain key) terminates the entire gateway process and all attached MCP sessions. No active session or credentials are required.

## Affected Component

- File: `src/gateways/stdioToSse.ts`
- Line 125: `const sessions: SseSessions = {}` (plain object inherits Object.prototype)
- Lines 222-239: Unguarded session lookup and `await session.transport.handlePostMessage(...)` in async route

## Impact

- Remote, unauthenticated, single-request denial of service against any default deployment
- All sessions and spawned MCP children die with the process
- No session needs to exist, and no credentials are required
- With default settings (--port without loopback restriction), attack works over network interfaces

## Proof of Concept

### Reproduction Steps

1. Clone the research repository: `git clone https://github.com/Teycir/supergateway-security-research`
2. Run bootstrap script: `./scripts/bootstrap.sh` (builds vulnerable supergateway v4.2.2)
3. Run exploit: `./pocs/rt01_exploit.sh http://127.0.0.1:8000`

### HTTP Request

```bash
curl -X POST "http://127.0.0.1:8000/message?sessionId=toString" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"test"}'
```

### Expected Result

Gateway process terminates with error:
```
TypeError: Cannot read properties of undefined (reading 'handlePostMessage')
    at .../dist/gateways/stdioToSse.js:135
```

Port becomes closed within 2 seconds.

### Verification Status

- 15/15 crashes across five prototype chain payloads (toString, __proto__, constructor, hasOwnProperty, valueOf)
- Reproduced over non-loopback interface
- Raw TCP reproduction included (using `nc`)
- All verification scripts in research repository pass

## Remediation

### Recommended Fix

Replace the plain object session store with a `Map` and validate ownership explicitly:

```typescript
// Before (vulnerable):
const sessions: SseSessions = {}

// After (fixed):
const sessions = new Map<string, SseSessionEntry>()
```

Validated patch available at: `patches/rt01-map-sessions.patch`

### Workarounds

1. Require `SUPERGATEWAY_API_KEY` environment variable (unauthenticated requests return 401)
2. Bind to loopback only and do not expose the SSE port publicly
3. Use stdio→Streamable HTTP mode instead (uses Map, not affected)

## References

- Upstream Repository: https://github.com/supercorp-ai/supergateway
- Research Repository: https://github.com/Teycir/supergateway-security-research
- Full Advisory: https://github.com/Teycir/supergateway-security-research/blob/main/advisories/SGW-2026-001.md
- GitHub Issue: https://github.com/supercorp-ai/supergateway/issues/378
- GHSA (fork): https://github.com/Teycir/supergateway/security/advisories/GHSA-96g7-x7h4-cr9v

## Timeline

- 2026-11-17: Vulnerability discovered and reproduced
- 2026-11-17: 36-check verification sweep completed (15/15 crashes)
- 2026-11-17: Patch validated (503 response, process stays alive)
- 2026-11-17: Research repository published
- 2026-11-17: Vendor contacted via public issue #378: https://github.com/supercorp-ai/supergateway/issues/378
- 2026-11-17: VulDB submission (this document)

## Credits

Research, exploit development, and report: Teycir (@Teycir)
