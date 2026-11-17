#!/usr/bin/env bash
# Regenerate SHA256SUMS over all tracked files (except SHA256SUMS itself).
set -euo pipefail
ENG="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ENG"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git ls-files -z | grep -zv '^SHA256SUMS$' | xargs -0 sha256sum > SHA256SUMS
else
  find . -type f ! -path './.git/*' ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
fi
echo "[+] wrote SHA256SUMS ($(wc -l < SHA256SUMS) files)"
