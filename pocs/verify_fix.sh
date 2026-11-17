#!/usr/bin/env bash
# Validates patches/rt01-map-sessions.patch: applies it, rebuilds, proves the
# crash is gone while a legitimate session still works, then restores the tree.
# Usage: ./verify_fix.sh
# Env:   REPO=<path>   default <repo>/.work/supergateway
set -uo pipefail
ENG="${ENG:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO="${REPO:-$ENG/.work/supergateway}"
EV="${EV:-$ENG/.artifacts}"
POC="$ENG/pocs"; PATCH="$ENG/patches/rt01-map-sessions.patch"
CANARY="${CANARY:-$ENG/evidence/canary.txt}"
APPLIED=0
restore() { if [ "$APPLIED" = 1 ]; then echo "[*] restoring source tree"; git -C "$REPO" checkout -- src; npm --prefix "$REPO" run build >/dev/null 2>&1; fi; }
trap restore EXIT
P=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
wait_http() { for _ in $(seq 1 50); do [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 1 "$1")" = 200 ] && return 0; sleep 0.1; done; return 1; }
mkdir -p "$EV"
cd "$REPO" || exit 1
echo "[*] git apply $PATCH"
git apply "$PATCH" || { echo "FAIL: patch did not apply"; exit 1; }
APPLIED=1
git diff --stat
npm run build >/dev/null 2>&1 || { echo "FAIL: patched build failed"; exit 1; }
echo "[*] patched build OK -> testing"
node dist/index.js --stdio "python3 $POC/canary_mcp_server.py" --port "$P" --baseUrl "http://127.0.0.1:$P" --healthEndpoint /healthz > "$EV/fix_gateway.log" 2>&1 &
G=$!; sleep 0.5
wait_http "http://127.0.0.1:$P/healthz" || { echo "FAIL: patched gateway did not start"; kill $G; exit 1; }
FAIL=0
for k in toString __proto__ constructor hasOwnProperty valueOf; do
  C=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$P/message?sessionId=$k")
  echo "  patched POST sessionId=$k -> $C"
  [ "$C" = 503 ] || FAIL=1
done
kill -0 $G 2>/dev/null && echo "  process=alive" || { echo "  process=dead"; FAIL=1; }
[ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$P/healthz")" = 200 ] && echo "  health=200" || FAIL=1
# legitimate session still works end to end
STREAM="$EV/fix_stream.log"
curl -sN --max-time 10 "http://127.0.0.1:$P/sse" > "$STREAM" 2>&1 &
VS=$!; SID=""; for _ in $(seq 1 40); do SID=$(sed -n 's/^data: .*sessionId=//p' "$STREAM" | head -1); [ -n "$SID" ] && break; sleep 0.1; done
curl -s -o /dev/null -X POST "http://127.0.0.1:$P/message?sessionId=$SID" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
curl -s -o /dev/null -X POST "http://127.0.0.1:$P/message?sessionId=$SID" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"read_file","arguments":{"path":"'"$CANARY"'"}}}'
for _ in $(seq 1 30); do grep -qF "$(cat "$CANARY")" "$STREAM" && break; sleep 0.1; done
grep -qF "$(cat "$CANARY")" "$STREAM" && echo "  legit tool call returned canary (session $SID)" || { echo "  legit tool call FAILED"; FAIL=1; }
kill $VS 2>/dev/null; kill $G 2>/dev/null
[ $FAIL -eq 0 ] && { echo "[+] FIX VALIDATED"; exit 0; } || { echo "[-] FIX VALIDATION FAILED"; exit 1; }
