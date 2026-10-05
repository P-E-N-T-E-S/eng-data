# CONTRATO — o verifica.sh lê estes nomes. Preserve-os na refatoração.
output "bucket_name" { value = module.lake.bucket_name }
output "database_name" { value = module.lake.database_name }
output "table_name" { value = module.lake.table_name }
output "workgroup_name" { value = module.lake.workgroup_name }
output "teto_bytes" { value = module.lake.teto_bytes }
