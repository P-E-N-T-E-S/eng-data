#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/ambiente.sh"
cd "$TF_DIR"

[[ "$(terraform workspace show)" == av2 ]] || { echo "Selecione o workspace av2" >&2; exit 1; }
python3 "$PROJETO/parte-2/verificacao/aceite.py" --confere-contexto
log_command destroy-av2 terraform destroy -no-color "$@"
python3 "$PROJETO/parte-2/verificacao/aceite.py" --backend-livre

[[ "$(terraform -chdir=bootstrap output -raw state_bucket)" == "$TF_VAR_state_bucket" ]] || {
  echo "Estado local do bootstrap não corresponde ao backend da AV2" >&2
  exit 1
}
log_command destroy-backend-av2 terraform -chdir=bootstrap destroy -no-color "$@"
"$PROJETO/parte-2/verificacao/verifica.sh" --pos-destroy
