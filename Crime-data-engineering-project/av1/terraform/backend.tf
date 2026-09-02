# Backend remoto: state fica no S3 + lock no DynamoDB (nunca no git).
#
# IMPORTANTE: o bucket e a tabela de lock PRECISAM existir antes do
# `terraform init`. Crie-os uma vez com:
#     ./bootstrap.sh
# (ou manualmente: aws s3 mb + aws dynamodb create-table)
#
# Se ainda nao criou, comente TODO este bloco e rode `terraform init`
# com backend local (state fica em terraform.tfstate — nao comite!).

terraform {
  backend "s3" {
    bucket         = "eda262-g04-tfstate"
    key            = "av1/crime/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eda262-g04-tfstate-lock"
    encrypt        = true
  }
}
