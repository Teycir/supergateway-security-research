# Technical analysis

All line numbers refer to supergateway `5ad19d3` (v4.2.2-4-g5ad19d3). Source hashes are recorded in `evidence/source_vulnerable_snippet.txt`.

## RT-01 / SGW-2026-001 — prototype-chain session lookup → process exit

### Code path

`src/gateways/stdioToSse.ts`

```ts
125  const sessions: SseSessions = {}
...
222  app.post(messagePath, async (req, res) => {
223    const sessionId = req.query.sessionId as string
...
231    const session = sessions[sessionId]
232    // A session is stored with its transport, and kept only while it is open.
233    if (session) {
234      logger.info(`POST to SSE transport (session ${sessionId})`)
235      await session.transport.handlePostMessage(req, res)
236    } else {
237      res.status(503).send(`No active SSE connection for session ${sessionId}`)
238    }
239  })
```

`sessions` is an object literal. A query value such as `toString` is not an own property, but `sessions["toString"]` returns `Object.prototype.toString`, a truthy function. `session.transport` is `undefined`, so `.handlePostMessage` throws.

### Why the process exits

1. The route callback is `async`. The `TypeError` rejects the promise it returns.
2. Express 4 (`express@4.22.3` in this build) does not await route handlers, so nothing catches the rejection.
3. supergateway installs no `unhandledRejection` handler.
4. Node.js (22.21.0 here; default since 15) turns an unhandled rejection into an uncaught exception and exits.

The child MCP process is a child of the gateway, so all sessions and tool state die with it.

### Trigger values

Every key resolving through `Object.prototype` is truthy and lacks `.transport`:

| Payload | `sessions[payload]` |
|---|---|
| `toString` | function |
| `constructor` | function (`Object`) |
| `__proto__` | `Object.prototype` (object, truthy) |
| `hasOwnProperty` | function |
| `valueOf` | function |

No prior `GET /sse` is needed: `sessions` exists from startup, so the request is unauthenticated and stateless from the attacker's point of view. Verified 15/15 and over a non-loopback interface.

### Related negative results

- Stateful Streamable HTTP uses a `Map` (`statefulSessions.ts`) and returns `404` for `mcp-session-id: toString`, staying alive.
- Enabling `SUPERGATEWAY_API_KEY` returns `401` before the handler, so the crash is not reachable unauthenticated in that configuration.
- Binding loopback-only reduces exposure but does not fix the bug (DNS rebinding and local malware/page attacks remain; the request is a plain HTTP POST, so a browser page can send it only cross-origin with preflight restrictions — CORS defaults are closed — but any local process can).

## RT-02 / SGW-2026-002 — WebSocket upgrade has no Origin policy

### Code path

`src/gateways/stdioToWs.ts` attaches a `WebSocketServer` to the HTTP server and accepts `upgrade` requests. The request headers are never checked for `Origin`, and authentication is opt-in. WebSocket handshakes are exempt from the same-origin policy, so a page on `http://evil.example` can open `ws://127.0.0.1:<port>/ws` and speak MCP JSON-RPC.

### Proof chain

1. Victim runs `supergateway --stdio "npx -y @modelcontextprotocol/server-filesystem /" --outputTransport ws --port 18081` (or any tool-bearing MCP server).
2. Victim visits an attacker page.
3. `new WebSocket('ws://127.0.0.1:18081/ws')` — browser performs the handshake with `Origin: http://evil.example`.
4. Gateway accepts, the page sends `initialize` + `tools/call read_file`.
5. Tool result is rendered/exfiltrated.

Captured evidence:

- `evidence/cswsh_handshake.log` — `101 Switching Protocols` for a hostile origin.
- `evidence/cswsh_browser.png` — real Chromium page (`http://127.0.0.1:8089`) with title `PWNED SGW-CANARY-…`.
- `evidence/received/exfil_proof.txt` — content delivered to the receiver.
- 12/12 runs across four origins (including `null`).

### Why `null` matters

Sandboxed iframes and some `file://`/data contexts send `Origin: null`. The server accepts it, so even pages with opaque origins can attack.

## RT-03: information disclosure in logs

`POST /message?sessionId=…` is logged at `info` with the full JSON-RPC body by the request logger (`src/lib/getLogger.ts` and the SSE transport logging path). Bodies routinely contain API keys for upstream MCP servers (`_meta`, tool arguments), file contents, and session IDs. A secret marker in `_meta.password` appeared verbatim in the log (3/3). Secondary effect: anyone with log access obtains live session IDs and can POST into those sessions.

Mitigation: redact `_meta`, `params.arguments`, and `Authorization`-like fields; log method and byte count only. This is not a separate remote primitive but it materially raises the impact of RT-01/RT-02 collected logs.
