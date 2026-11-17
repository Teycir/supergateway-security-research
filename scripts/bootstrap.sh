#!/usr/bin/env bash
# Fetch and build the vulnerable supergateway tree pinned by this research.
set -euo pipefail
ENG="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${REPO:-$ENG/.work/supergateway}"
PIN="5ad19d39c033fde33f18c2edefa996771980aafe"
mkdir -p "$(dirname "$REPO")"
if [ ! -d "$REPO/.git" ]; then
  echo "[*] cloning supergateway"
  git clone https://github.com/supercorp-ai/supergateway.git "$REPO"
fi
echo "[*] checking out $PIN"
git -C "$REPO" fetch --all --tags -q || true
git -C "$REPO" checkout -q "$PIN"
echo "[*] npm ci"
if [ -f "$REPO/package-lock.json" ]; then npm --prefix "$REPO" ci --no-audit --no-fund; else npm --prefix "$REPO" install --no-audit --no-fund; fi
echo "[*] npm run build"
npm --prefix "$REPO" run build
echo "[+] vulnerable build ready: $REPO ($(git -C "$REPO" rev-parse --short HEAD))"
