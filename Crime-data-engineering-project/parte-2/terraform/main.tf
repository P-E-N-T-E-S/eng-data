module "platform" {
  source = "./modules/platform"

  raw_bucket_name     = var.raw_bucket_name
  trusted_bucket_name = var.trusted_bucket_name
  refined_bucket_name = var.refined_bucket_name
  workgroup_name      = var.workgroup_name
  years               = var.years
  query_target_bytes  = var.query_target_bytes
  query_cutoff_bytes  = var.query_cutoff_bytes
}
