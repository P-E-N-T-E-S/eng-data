#!/usr/bin/env bash
# Derruba tudo da AV1 g04 e prova que nao sobrou nada.
#   ./destroy.sh
set -euo pipefail
cd "$(dirname "$0")"
REGIAO="us-east-1"
BUCKET="eda262-g04-lake-trusted"

esvaziar_bucket_versionado() {
  while :; do
    objetos="$({ aws s3api list-object-versions --bucket "$BUCKET" --region "$REGIAO" --output json; } | python3 -c '
import json, sys
data = json.load(sys.stdin)
objects = [
    {"Key": item["Key"], "VersionId": item["VersionId"]}
    for section in ("Versions", "DeleteMarkers")
    for item in data.get(section, [])
]
print(json.dumps({"Objects": objects, "Quiet": True}))
')"

    if [[ "$objetos" == '{"Objects": [], "Quiet": true}' ]]; then
      return
    fi

    aws s3api delete-objects \
      --bucket "$BUCKET" \
      --region "$REGIAO" \
      --delete "$objetos" \
      --output text >/dev/null
  done
}

echo "esvaziando todas as versoes de s3://${BUCKET}"
if aws s3api head-bucket --bucket "$BUCKET" --region "$REGIAO" 2>/dev/null; then
  esvaziar_bucket_versionado
fi

terraform destroy -auto-approve
terraform output 2>/dev/null || true
echo "destroy concluido. rode ./verificacao/verifica.sh --pos-destroy para conferir orfaos."
