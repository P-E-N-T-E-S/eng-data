#!/usr/bin/env bash
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJETO="$(cd "$TF_DIR/../.." && pwd -P)"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION" AWS_PAGER=""
export TF_VAR_region="$AWS_REGION"

CONTA="$(aws sts get-caller-identity --region "$AWS_REGION" --query Account --output text)"
[[ "$CONTA" =~ ^[0-9]{12}$ ]] || { echo "Conta AWS inválida" >&2; exit 1; }

export TF_VAR_state_bucket="eda262-g04-tfstate-av2-$CONTA"
export TF_VAR_lock_table="eda262-g04-tfstate-lock-av2"
export TF_VAR_raw_bucket_name="${AV2_RAW_BUCKET:-eda262-g04-lake-raw}"
export TF_VAR_trusted_bucket_name="${AV2_TRUSTED_BUCKET:-eda262-g04-lake-trusted}"
export TF_VAR_refined_bucket_name="${AV2_REFINED_BUCKET:-eda262-g04-lake-refined}"
export AV2_CONTA="$CONTA" AV2_PROJETO="$PROJETO"
unset TF_WORKSPACE

log_command() {
  local prefix="$1" log
  shift
  mkdir -p "$PROJETO/evidencias"
  log="$(mktemp --suffix=.txt "$PROJETO/evidencias/$prefix-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
  "$@" 2>&1 | tee "$log"
}
