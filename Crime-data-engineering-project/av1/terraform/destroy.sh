#!/usr/bin/env bash
# Derruba tudo da AV1 g04 e prova que nao sobrou nada.
#   ./destroy.sh
set -euo pipefail
cd "$(dirname "$0")"
REGIAO="us-east-1"
BUCKET="eda262-g04-lake-trusted"

echo "esvaziando s3://${BUCKET}"
aws s3 rm "s3://${BUCKET}" --recursive --region "$REGIAO" --only-show-errors || true

terraform destroy -auto-approve
terraform output 2>/dev/null || true
echo "destroy concluido. rode ./verificacao/verifica.sh --pos-destroy para conferir orfaos."
