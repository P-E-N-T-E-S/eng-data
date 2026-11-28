# Preserva os endereços da AV1 ao aplicar sobre o mesmo estado.
moved {
  from = aws_s3_bucket.trusted
  to   = module.lake.aws_s3_bucket.trusted
}

moved {
  from = aws_s3_bucket_versioning.trusted
  to   = module.lake.aws_s3_bucket_versioning.trusted
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.trusted
  to   = module.lake.aws_s3_bucket_server_side_encryption_configuration.trusted
}

moved {
  from = aws_s3_bucket_public_access_block.trusted
  to   = module.lake.aws_s3_bucket_public_access_block.trusted
}

moved {
  from = aws_glue_catalog_database.crime
  to   = module.lake.aws_glue_catalog_database.crime
}

moved {
  from = aws_glue_catalog_table.crime_trusted
  to   = module.lake.aws_glue_catalog_table.crime_trusted
}

moved {
  from = aws_glue_partition.ano
  to   = module.lake.aws_glue_partition.ano
}

moved {
  from = aws_athena_workgroup.crime
  to   = module.lake.aws_athena_workgroup.crime
}
