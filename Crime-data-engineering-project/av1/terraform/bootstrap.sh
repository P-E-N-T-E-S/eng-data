#!/usr/bin/env bash
# Cria o backend remoto do Terraform (S3 + DynamoDB lock) UMA vez.
# Rode antes do primeiro `terraform init`. Idempotente.
set -euo pipefail
REGIAO="us-east-1"
BUCKET="eda262-g04-tfstate"
LOCK="eda262-g04-tfstate-lock"

echo "criando bucket de state: ${BUCKET}"
aws s3 mb "s3://${BUCKET}" --region "$REGIAO" 2>/dev/null || echo "  (ja existe)"

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" --versioning-configuration Status=Enabled --region "$REGIAO"

aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --region "$REGIAO"

echo "criando tabela de lock: ${LOCK}"
aws dynamodb create-table \
  --table-name "$LOCK" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGIAO" 2>/dev/null || echo "  (ja existe)"

echo "pronto. agora rode: terraform init && terraform apply"
