output "bucket_name" {
  value = module.lake.bucket_name
}

output "database_name" {
  value = module.lake.database_name
}

output "table_name" {
  value = module.lake.table_name
}

output "workgroup_name" {
  value = module.lake.workgroup_name
}

output "bytes_cutoff" {
  value = module.lake.bytes_cutoff
}

output "anos" {
  value = var.anos
}
