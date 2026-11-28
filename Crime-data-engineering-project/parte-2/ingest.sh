#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/terraform/ambiente.sh"

csv_dir="$PROJETO/parte-1/dados"
for year in 2024 2025 2026; do
  file="$csv_dir/BancoVDE_${year}.csv"
  [[ -s "$file" ]] || {
    echo "CSV ausente: $file. Execute o conversor da parte 1." >&2
    exit 1
  }
done

python3 "$PROJETO/parte-2/verificacao/aceite.py" --confere-contexto
bucket="$(terraform -chdir="$TF_DIR" output -raw raw_bucket)"
for year in 2024 2025 2026; do
  file="$csv_dir/BancoVDE_${year}.csv"
  aws s3api put-object \
    --bucket "$bucket" \
    --key "crime/ano=$year/BancoVDE_${year}.csv" \
    --body "$file" \
    --checksum-algorithm SHA256 \
    --expected-bucket-owner "$CONTA" >/dev/null
  echo "raw $year carregada"
done
