terraform {
  backend "s3" {
    key     = "av2/crime/terraform.tfstate"
    encrypt = true
  }
}
