#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/ambiente.sh"
cd "$TF_DIR"
terraform init -input=false -backend-config="bucket=$TF_VAR_state_bucket" \
  -backend-config="region=$AWS_REGION" -backend-config="dynamodb_table=$TF_VAR_lock_table"
terraform workspace select -or-create av1
log_terraform deploy terraform apply -no-color "$@"
# Persistir os nomes efetivos para auditar a ausência dos recursos depois do destroy.
mkdir -p "$PROJETO/.av1"
tmp="$(mktemp "$PROJETO/.av1/inventario.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
terraform output -json > "$tmp"
python3 - "$tmp" <<'PY'
import json, os, sys
from pathlib import Path
p = Path(sys.argv[1])
outputs = {k: v["value"] for k, v in json.loads(p.read_text()).items()}
outputs.update(conta=os.environ["AV1_CONTA"], region=os.environ["AWS_REGION"],
               state_bucket=os.environ["TF_VAR_state_bucket"], lock_table=os.environ["TF_VAR_lock_table"])
p.write_text(json.dumps(outputs, indent=2) + "\n")
PY
mv "$tmp" "$PROJETO/.av1/inventario.json"
