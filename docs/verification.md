# Verification

Everything below was produced in an isolated lab: Kali Linux, Node.js 22.21.0, npm 11.10.0, supergateway at `5ad19d3` (v4.2.2), loopback plus one non-loopback interface (`10.0.2.15`).

## Harness

- `pocs/verify_all.sh [rounds]` — end-to-end sweep. Starts isolated gateways on ephemeral ports, uses a deterministic MCP stdio server (`pocs/canary_mcp_server.py`) and a canary file (`evidence/canary.txt`, `SGW-CANARY-7f3a9c1e-DO-NOT-LEAK`), and writes runtime logs to `.artifacts/`.
- `pocs/verify_fix.sh` — applies `patches/rt01-map-sessions.patch`, rebuilds, tests, then restores the source tree and rebuilds.
- `scripts/reproduce.sh` — bootstrap + both of the above.

## Results (2026-11-17, UTC)

| Area | Checks | Result |
|---|---|---|
| RT-01 payload sweep (`toString`, `__proto__`, `constructor`, `hasOwnProperty`, `valueOf` × 3) | 15 | 15/15 crash: curl `000`, port closed ≤2 s, health `000` |
| RT-01 non-loopback (`10.0.2.15`, unauthenticated) | 1 | crash |
| RT-01 API-key negative control | 3 | `401`, process alive each run |
| RT-02 origins (`http://evil.example`, `null`, `https://attacker.test:4443`, `http://localhost:9999` × 3) | 12 | 12/12 canary exfiltrated and received |
| RT-02 key negative / positive | 2 | unauthenticated upgrade refused (exit 2); `Authorization: Bearer K3yTest` allowed |
| RT-03 secret marker in `info` log | 3 | 3/3 marker present, POST `202` |
| **Total** | **36** | **36 passed, 0 failed** |

Summary log: `evidence/verification/summary_203133.log` (started 2026-11-17T20:31:33Z).

Additional reproductions:

- Raw TCP without `curl` (`nc`) → process dead, health `000`: `evidence/rt01_raw_netcat.log`.
- Real browser CSWSH proof in headless Chromium: `evidence/cswsh_browser.png`, run log `evidence/cswsh_browser_run.log`.
- Stateful Streamable HTTP negative control: `evidence/stateful_proto_negative.log`.

## Fix validation (2026-11-17T20:32:21Z)

```text
[*] git apply patches/rt01-map-sessions.patch
 src/gateways/sseSession.ts | 30 ++++++++++++++++--------------
 src/gateways/stdioToSse.ts | 11 ++++++++---
 2 files changed, 24 insertions(+), 17 deletions(-)
[*] patched build OK -> testing
  patched POST sessionId=toString -> 503
  patched POST sessionId=__proto__ -> 503
  patched POST sessionId=constructor -> 503
  patched POST sessionId=hasOwnProperty -> 503
  patched POST sessionId=valueOf -> 503
  process=alive
  health=200
  legit tool call returned canary (session 034fb3e2-…)
[*] restoring source tree
[+] FIX VALIDATED
```

After restoring, a fresh build reproduced the crash again (`evidence/post_restore_crash.log`), proving the validation was against the patched artifact and the vulnerable build was restored.

## Re-running

```bash
./scripts/bootstrap.sh
REPO=$PWD/.work/supergateway ./pocs/verify_all.sh 3
REPO=$PWD/.work/supergateway ./pocs/verify_fix.sh
```

Runtime artifacts (`.artifacts/`) are git-ignored; committed evidence is the frozen capture listed in `evidence/README.md` and hashed in `SHA256SUMS`.
