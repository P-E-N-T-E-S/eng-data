terraform {
  backend "s3" {
    key     = "av1/crime/terraform.tfstate"
    encrypt = true
  }
}
