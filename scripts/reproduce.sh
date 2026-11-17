#!/usr/bin/env bash
# Full reproduction: fetch/build the pinned vulnerable tree, run the checks,
# then validate the proposed fix (the fix script restores the tree afterwards).
# Usage: ./scripts/reproduce.sh [rounds]     (default 3; use 1 for a smoke test)
set -euo pipefail
ENG="$(cd "$(dirname "$0")/.." && pwd)"
ROUNDS="${1:-3}"
"$ENG/scripts/bootstrap.sh"
REPO="${REPO:-$ENG/.work/supergateway}" "$ENG/pocs/verify_all.sh" "$ROUNDS"
REPO="${REPO:-$ENG/.work/supergateway}" "$ENG/pocs/verify_fix.sh"
echo "[+] reproduction complete; artifacts in $ENG/.artifacts"
