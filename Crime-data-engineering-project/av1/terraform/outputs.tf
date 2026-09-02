output "bucket_name" {
  description = "Bucket do lake trusted."
  value       = aws_s3_bucket.trusted.bucket
}

output "database_name" {
  description = "Database no Glue Data Catalog."
  value       = aws_glue_catalog_database.crime.name
}

output "table_name" {
  description = "Tabela declarada (sem crawler)."
  value       = aws_glue_catalog_table.crime_trusted.name
}

output "workgroup_name" {
  description = "Workgroup do Athena."
  value       = aws_athena_workgroup.crime.name
}

output "bytes_cutoff" {
  description = "Teto de bytes por consulta (DECISAO 05)."
  value       = var.bytes_scanned_cutoff
}
