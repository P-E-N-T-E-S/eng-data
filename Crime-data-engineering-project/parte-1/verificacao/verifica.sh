#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/../../verificacao/verifica.sh" --av1 "$@"
