# Evidence

Frozen capture from the lab runs (2026-11-17, UTC). Logs contain lab paths (`/home/kali/BugBounty/...`), test values (test API key `K3yTest`), and the canary `SGW-CANARY-7f3a9c1e-DO-NOT-LEAK`; none are production secrets.

| File | Proves |
|---|---|
| `canary.txt` | Victim file used as the exfiltration target |
| `source_vulnerable_snippet.txt` | Vulnerable code at `5ad19d3` + source hashes |
| `versions.txt` | Commit, Node/npm versions, dependency set |
| `gw_sse_crash.log` | RT-01 stack trace after the malicious POST |
| `rt01_raw_netcat.log`, `rt01_raw_gateway.log` | RT-01 reproduction over raw TCP, no `curl` |
| `sse_dos_apikey_negative.log` | RT-01 blocked by API key (`401`) |
| `stateful_proto_negative.log` | Streamable HTTP is not vulnerable (`404`, alive) |
| `cswsh_handshake.log` | `101 Switching Protocols` for hostile `Origin` |
| `cswsh_run.log`, `cswsh_browser_run.log`, `cswsh_browser_dom.html` | Node and real-browser CSWSH runs |
| `cswsh_browser.png` | Chromium page showing `PWNED SGW-CANARY-…` |
| `cswsh_proof.txt`, `received/exfil_proof.txt` | Exfiltrated canary delivered to the receiver |
| `ws_apikey_negative.log` | Unauthenticated WebSocket upgrade refused when key is set |
| `verification/summary_203133.log` | 36/36 pass summary and per-check lines |
| `fix_validation.log` | Patch applied, `503` for all payloads, alive, functional session, restored |
| `post_restore_crash.log` | Vulnerability returns after restoring the vulnerable build |
| `gw_log_leak.log`, `log_leak_evidence.txt` | RT-03 secret marker logged |

Files are hashed in `SHA256SUMS` at the repository root. Re-check with:

```bash
sha256sum -c SHA256SUMS
```
