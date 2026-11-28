#!/usr/bin/env bash
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd -P)"
destino="${1:-$dir/../data/raw}"
base="https://www.gov.br/mj/pt-br/assuntos/sua-seguranca/seguranca-publica/estatistica/download/dnsp-base-de-dados"
mkdir -p "$destino"
cd "$destino"
temp="$(mktemp .bancovde-XXXXXX)"
trap 'rm -f "$temp"' EXIT
for ano in 2024 2025 2026; do
  arquivo="BancoVDE $ano.xlsx"
  esperado="$(awk -v ano="$ano.xlsx" '$NF == ano {print $1}' "$dir/originais.sha256")"
  if [[ -f "$arquivo" ]]; then
    printf '%s  %s\n' "$esperado" "$arquivo" | sha256sum -c -
    continue
  fi
  curl --fail --location --retry 2 --silent --show-error "$base/bancovde-$ano.xlsx/@@download/file" -o "$temp"
  printf '%s  %s\n' "$esperado" "$temp" | sha256sum -c -
  mv "$temp" "$arquivo"
done
