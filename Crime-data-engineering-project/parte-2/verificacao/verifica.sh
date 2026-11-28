#!/usr/bin/env bash
set -euo pipefail
raiz="$(cd "$(dirname "$0")/../.." && pwd -P)"
mkdir -p "$raiz/evidencias"
log="$(mktemp --suffix=.txt "$raiz/evidencias/verifica-av2-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
python3 "$raiz/parte-2/verificacao/aceite.py" "$@" 2>&1 | tee "$log"
