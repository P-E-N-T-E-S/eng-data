#!/usr/bin/env bash
# Aplica a stack da AV1 g04 (Terraform). Rode de dentro de av1/terraform/.
#   ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"
terraform init
terraform apply -auto-approve
terraform output
