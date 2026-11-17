# Remediation

## SGW-2026-001 (prototype-key DoS)

`patches/rt01-map-sessions.patch` is the tested fix. It changes session storage from a plain object to a `Map` and makes the lookup explicit.

Core change in `src/gateways/stdioToSse.ts`:

```ts
- const sessions: SseSessions = {}
+ const sessions = new Map<string, SseSession>()
...
- const session = sessions[sessionId]
+ const session = sessions.get(sessionId)
```

`src/gateways/sseSession.ts` is updated accordingly (create/get/delete helpers), preserving the “session kept only while transport is open” lifecycle. Unknown or non-string keys can no longer resolve to inherited properties and are answered with `503`.

Validation:

- All five prototype payloads → `503`, process alive, health `200`.
- A legitimate SSE session still initializes and completes `tools/call read_file` returning the canary.
- Source tree restored and rebuilt afterwards; the crash returns, so the test isolates the patch.

Minimal hardening if a full patch is not taken: `Object.create(null)` or `Object.hasOwn(sessions, sessionId)` before access. Prefer the `Map` version.

## SGW-2026-002 (CSWSH)

No upstream patch exists; recommended changes:

1. During `upgrade`, parse `Origin` and reject unless it matches an allowlist. Default allowlist: `http://127.0.0.1:<port>`, `http://localhost:<port>`, and explicitly configured origins. Reject `null` by default.
2. Apply the same API-key check to WebSocket upgrades as to HTTP routes; do not allow “no key configured” to imply “no check” when the port is reachable beyond loopback.
3. Bind loopback unless `--host` is explicit, and warn when binding non-loopback without a key.
4. Add a `--allowedOrigins` option with a documented default.

## RT-03 (log disclosure)

- Redact request bodies before logging; log JSON-RPC `method` and byte length.
- Redact `_meta`, tool `arguments`, `Authorization`, `X-API-Key`, and `Cookie`.
- Consider logging session IDs only at `debug`.
- Rotate/restrict access to gateway logs; they may contain upstream MCP credentials.

## Operator mitigations (no code change)

- Set `SUPERGATEWAY_API_KEY` (verified to stop RT-01 unauthenticated and RT-02 unauthenticated).
- Keep the port on loopback; never expose it directly.
- Use stdio→Streamable HTTP stateful mode where possible (not affected by RT-01).
- Restrict log access; treat gateway logs as sensitive.
