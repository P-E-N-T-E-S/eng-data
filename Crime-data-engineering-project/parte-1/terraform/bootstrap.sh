#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/ambiente.sh"
cd "$TF_DIR/bootstrap"
terraform init -input=false
log_terraform bootstrap terraform apply -no-color "$@"
