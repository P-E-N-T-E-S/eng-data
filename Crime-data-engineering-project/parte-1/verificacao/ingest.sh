#!/usr/bin/env bash
set -euo pipefail
dir="$(cd "$(dirname "$0")/../dados" && pwd -P)"
for ano in 2024 2025 2026; do
  [[ -s "$dir/BancoVDE_${ano}.csv" ]] || { echo "[FALHA] CSV ausente ou vazio: $ano" >&2; exit 1; }
done
source "$(dirname "$0")/../terraform/ambiente.sh"
python3 "$PROJETO/verificacao/aceite.py" --confere-contexto
bucket="$(terraform -chdir="$TF_DIR" output -raw bucket_name)"
for ano in 2024 2025 2026; do
  aws s3api put-object --bucket "$bucket" --key "crime/ano=$ano/BancoVDE_${ano}.csv" \
    --body "$dir/BancoVDE_${ano}.csv" --checksum-algorithm SHA256 --expected-bucket-owner "$CONTA" >/dev/null
done
