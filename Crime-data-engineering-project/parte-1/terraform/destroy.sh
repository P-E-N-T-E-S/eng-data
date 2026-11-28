#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/ambiente.sh"
cd "$TF_DIR"
[[ "$(terraform workspace show)" == av1 ]] || { echo "Selecione o workspace av1 do deploy" >&2; exit 1; }
# Conferir a conta, o backend inicializado e os nomes antes de usar force_destroy.
python3 "$PROJETO/verificacao/aceite.py" --confere-contexto
[[ "$(terraform -chdir=bootstrap output -raw state_bucket)" == "$TF_VAR_state_bucket" &&
   "$(terraform -chdir=bootstrap output -raw lock_table)" == "$TF_VAR_lock_table" ]] || {
  echo "Estado local do bootstrap não corresponde ao backend do deploy" >&2
  exit 1
}
log_terraform destroy-lake terraform destroy -no-color "$@"
# O backend é exclusivo desta parte. Recusar estados ativos e objetos imprevistos.
python3 "$PROJETO/verificacao/aceite.py" --backend-livre
log_terraform destroy-backend terraform -chdir=bootstrap destroy -no-color "$@"
"$PROJETO/verificacao/verifica.sh" --pos-destroy
