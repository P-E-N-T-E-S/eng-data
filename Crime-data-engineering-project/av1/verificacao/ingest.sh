#!/usr/bin/env bash
# Ingestao dos CSVs de crime no S3 trusted (1 arquivo por particao de ano).
# Rode da raiz de av1/ DEPOIS do terraform apply.
#
#   ./verificacao/ingest.sh
set -euo pipefail
REGIAO="us-east-1"
BUCKET="eda262-g04-lake-trusted"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DADOS="${RAIZ}/dados"

for ano in 2024 2025 2026; do
  arq="${DADOS}/BancoVDE_${ano}.csv"
  if [[ ! -f "$arq" ]]; then
    echo "AVISO: ${arq} nao encontrado, pulando" >&2
    continue
  fi
  dest="s3://${BUCKET}/crime/ano=${ano}/BancoVDE_${ano}.csv"
  echo "subindo ${arq} -> ${dest}"
  aws s3 cp "$arq" "$dest" --region "$REGIAO"
done

echo
echo "pronto. confira no Athena (workgroup eda262-g04-crime-wg):"
echo "  SELECT uf, ano, SUM(total_vitima) AS homicidios"
echo "  FROM \"eda262_g04_crime_db\".\"crime_trusted\""
echo "  WHERE evento ILIKE '%Homicidio%' AND evento NOT ILIKE '%Tentativa%'"
echo "  GROUP BY uf, ano ORDER BY uf, ano;"
