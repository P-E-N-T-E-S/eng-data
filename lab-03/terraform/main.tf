module "lake" {
  source     = "./modules/lake"
  sufixo     = var.sufixo
  teto_bytes = var.teto_bytes
}
