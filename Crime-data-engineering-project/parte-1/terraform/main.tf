module "lake" {
  source = "./modules/lake"

  bucket_name          = var.bucket_name
  database_name        = var.database_name
  table_name           = var.table_name
  workgroup_name       = var.workgroup_name
  bytes_scanned_cutoff = var.bytes_scanned_cutoff
  anos                 = var.anos
}
