#!/usr/bin/env bash
# Configuração compartilhada pelos pontos de entrada da AV1.
TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJETO="$(cd "$TF_DIR/../.." && pwd -P)"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_PAGER="" AWS_DEFAULT_REGION="$AWS_REGION" TF_VAR_region="$AWS_REGION"
CONTA="$(aws sts get-caller-identity --region "$AWS_REGION" --query Account --output text)"
[[ "$CONTA" =~ ^[0-9]{12}$ ]] || { echo "Conta AWS inválida" >&2; exit 1; }
export TF_VAR_state_bucket="eda262-g04-tfstate-$CONTA"
export TF_VAR_lock_table="eda262-g04-tfstate-lock-av1"
export TF_VAR_bucket_name="${AV1_BUCKET:-eda262-g04-lake-trusted}"
export AV1_CONTA="$CONTA" AV1_PROJETO="$PROJETO"
# O bootstrap usa o estado local default. O lake seleciona av1 no deploy.
unset TF_WORKSPACE

log_terraform() {
  local log
  mkdir -p "$PROJETO/evidencias"
  log="$(mktemp --suffix=.txt "$PROJETO/evidencias/$1-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
  shift
  "$@" 2>&1 | tee "$log"
}
