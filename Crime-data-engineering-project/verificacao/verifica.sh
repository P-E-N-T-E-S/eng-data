#!/usr/bin/env bash
set -euo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd -P)"

if [[ "${1:-}" == "--av1" ]]; then
  shift
  mkdir -p "$raiz/evidencias"
  export AV1_EVIDENCIAS
  AV1_EVIDENCIAS="$(mktemp -d "$raiz/evidencias/av1-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
  printf 'Evidências AV1: %s\n' "$AV1_EVIDENCIAS"
  python3 "$raiz/verificacao/aceite.py" "$@" 2>&1 | tee "$AV1_EVIDENCIAS/verifica.txt"
else
  exec "$raiz/parte-2/verificacao/verifica.sh" "$@"
fi
