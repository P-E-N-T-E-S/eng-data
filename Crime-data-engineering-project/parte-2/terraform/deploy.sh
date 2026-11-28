#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/ambiente.sh"
cd "$TF_DIR"

if ! aws s3api head-bucket --bucket "$TF_VAR_state_bucket" --expected-bucket-owner "$CONTA" 2>/dev/null; then
  "$TF_DIR/bootstrap.sh" -auto-approve
fi

terraform init -input=false -reconfigure \
  -backend-config="bucket=$TF_VAR_state_bucket" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="dynamodb_table=$TF_VAR_lock_table"
terraform workspace select -or-create av2
log_command deploy-av2 terraform apply -no-color "$@"

mkdir -p "$PROJETO/.av2"
tmp="$(mktemp "$PROJETO/.av2/inventario.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
terraform output -json > "$tmp"
python3 - "$tmp" <<'PY'
import json, os, sys
from pathlib import Path

path = Path(sys.argv[1])
outputs = {name: item["value"] for name, item in json.loads(path.read_text()).items()}
outputs.update(
    account=os.environ["AV2_CONTA"],
    region=os.environ["AWS_REGION"],
    state_bucket=os.environ["TF_VAR_state_bucket"],
    lock_table=os.environ["TF_VAR_lock_table"],
)
path.write_text(json.dumps(outputs, indent=2) + "\n")
PY
mv "$tmp" "$PROJETO/.av2/inventario.json"
