terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Credenciais vindo de ~/.aws/credentials ou das variaveis de ambiente
# AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY. Nada hardcoded.
provider "aws" {
  region = var.region
}
