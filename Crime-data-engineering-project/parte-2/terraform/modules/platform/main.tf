locals {
  buckets = {
    raw     = var.raw_bucket_name
    trusted = var.trusted_bucket_name
    refined = var.refined_bucket_name
  }

  databases = {
    raw     = "eda262_g04_crime_raw"
    trusted = "eda262_g04_crime_trusted"
    refined = "eda262_g04_crime_refined"
  }

  physical_columns = [
    ["uf", "string"],
    ["municipio", "string"],
    ["evento", "string"],
    ["data_referencia", "date"],
    ["agente", "string"],
    ["arma", "string"],
    ["faixa_etaria", "string"],
    ["feminino", "int"],
    ["masculino", "int"],
    ["nao_informado", "int"],
    ["total_vitima", "int"],
    ["total", "int"],
    ["total_peso", "double"],
    ["abrangencia", "string"],
    ["mes", "int"],
  ]

  parquet = {
    input  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    serde  = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "layer" {
  for_each      = local.buckets
  bucket        = each.value
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "layer" {
  for_each = aws_s3_bucket.layer
  bucket   = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "layer" {
  for_each = aws_s3_bucket.layer
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "layer" {
  for_each                = aws_s3_bucket.layer
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_glue_catalog_database" "layer" {
  for_each    = local.databases
  name        = each.value
  description = "Crime Brasil — camada ${each.key}."
}

resource "aws_glue_catalog_table" "raw" {
  name          = "crime"
  database_name = aws_glue_catalog_database.layer["raw"].name
  table_type    = "EXTERNAL_TABLE"
  description   = "Uma linha por registro recebido do BancoVDE, preservada em CSV por ano."

  parameters = {
    classification           = "csv"
    "skip.header.line.count" = "1"
    grao                     = "uma linha por registro recebido do BancoVDE"
    formato                  = "CSV UTF-8"
  }

  partition_keys {
    name    = "ano"
    type    = "int"
    comment = "Ano de referência do arquivo de origem."
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.layer["raw"].id}/crime/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"               = ","
        "escape.delim"              = "\\"
        "serialization.null.format" = "~"
      }
    }

    dynamic "columns" {
      for_each = local.physical_columns
      content {
        name = columns.value[0]
        type = columns.value[1]
      }
    }
  }
}

resource "aws_glue_catalog_table" "trusted" {
  name          = "crime"
  database_name = aws_glue_catalog_database.layer["trusted"].name
  table_type    = "EXTERNAL_TABLE"
  description   = "Uma linha tipada por registro do BancoVDE, em Parquet e particionada por ano."

  parameters = {
    classification = "parquet"
    grao           = "uma linha por registro recebido do BancoVDE"
    formato        = "Parquet Snappy"
    idempotencia   = "substituicao deterministica da particao anual"
  }

  partition_keys {
    name    = "ano"
    type    = "int"
    comment = "Ano de referência do registro."
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.layer["trusted"].id}/crime_parquet/"
    input_format  = local.parquet.input
    output_format = local.parquet.output

    ser_de_info {
      serialization_library = local.parquet.serde
    }

    dynamic "columns" {
      for_each = local.physical_columns
      content {
        name = columns.value[0]
        type = columns.value[1]
      }
    }
  }
}

resource "aws_glue_catalog_table" "refined" {
  name          = "homicidios_uf"
  database_name = aws_glue_catalog_database.layer["refined"].name
  table_type    = "EXTERNAL_TABLE"
  description   = "Vítimas de homicídio doloso por UF e ano na abrangência Estadual, com cobertura mensal."

  parameters = {
    classification = "parquet"
    grao           = "uma linha por UF e ano"
    formato        = "Parquet Snappy"
    dono           = "engenharia-de-dados-g04"
    atualizacao    = "após ingestão ou backfill de uma partição anual"
    meta_custo     = "até ${var.query_target_bytes} bytes por consulta anual"
  }

  partition_keys {
    name    = "ano"
    type    = "int"
    comment = "Ano de referência do indicador."
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.layer["refined"].id}/homicidios_uf/"
    input_format  = local.parquet.input
    output_format = local.parquet.output

    ser_de_info {
      serialization_library = local.parquet.serde
    }

    columns {
      name    = "uf"
      type    = "string"
      comment = "Sigla da Unidade da Federação."
    }
    columns {
      name    = "vitimas"
      type    = "bigint"
      comment = "Soma de total_vitima para homicídio doloso na abrangência Estadual."
    }
    columns {
      name    = "meses_informados"
      type    = "bigint"
      comment = "Meses distintos com total_vitima informado para a UF e o ano."
    }
  }
}

resource "aws_glue_partition" "raw" {
  for_each         = toset(var.years)
  database_name    = aws_glue_catalog_database.layer["raw"].name
  table_name       = aws_glue_catalog_table.raw.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.layer["raw"].id}/crime/ano=${each.value}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"               = ","
        "escape.delim"              = "\\"
        "serialization.null.format" = "~"
      }
    }
    dynamic "columns" {
      for_each = local.physical_columns
      content {
        name = columns.value[0]
        type = columns.value[1]
      }
    }
  }
}

resource "aws_glue_partition" "trusted" {
  for_each         = toset(var.years)
  database_name    = aws_glue_catalog_database.layer["trusted"].name
  table_name       = aws_glue_catalog_table.trusted.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.layer["trusted"].id}/crime_parquet/ano=${each.value}/"
    input_format  = local.parquet.input
    output_format = local.parquet.output
    ser_de_info { serialization_library = local.parquet.serde }
    dynamic "columns" {
      for_each = local.physical_columns
      content {
        name = columns.value[0]
        type = columns.value[1]
      }
    }
  }
}

resource "aws_glue_partition" "refined" {
  for_each         = toset(var.years)
  database_name    = aws_glue_catalog_database.layer["refined"].name
  table_name       = aws_glue_catalog_table.refined.name
  partition_values = [each.value]

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.layer["refined"].id}/homicidios_uf/ano=${each.value}/"
    input_format  = local.parquet.input
    output_format = local.parquet.output
    ser_de_info { serialization_library = local.parquet.serde }
    columns {
      name    = "uf"
      type    = "string"
      comment = "Sigla da Unidade da Federação."
    }
    columns {
      name    = "vitimas"
      type    = "bigint"
      comment = "Soma de vítimas do recorte."
    }
    columns {
      name    = "meses_informados"
      type    = "bigint"
      comment = "Cobertura mensal do recorte."
    }
  }
}

resource "aws_iam_role" "job" {
  name = "eda262-g04-crime-av2-glue"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "glue.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "job" {
  role       = aws_iam_role.job.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "job_storage" {
  name = "camadas"
  role = aws_iam_role.job.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [for bucket in aws_s3_bucket.layer : "${bucket.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [for bucket in aws_s3_bucket.layer : bucket.arn]
      },
    ]
  })
}

resource "aws_s3_object" "pipeline" {
  bucket = aws_s3_bucket.layer["raw"].id
  key    = "scripts/pipeline_crime.py"
  source = "${path.module}/scripts/pipeline_crime.py"
  etag   = filemd5("${path.module}/scripts/pipeline_crime.py")
}

resource "aws_glue_job" "pipeline" {
  name              = "eda262-g04-crime-av2"
  role_arn          = aws_iam_role.job.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30
  max_retries       = 0

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.layer["raw"].id}/${aws_s3_object.pipeline.key}"
  }

  default_arguments = {
    "--RAW_BUCKET"          = aws_s3_bucket.layer["raw"].id
    "--TRUSTED_BUCKET"      = aws_s3_bucket.layer["trusted"].id
    "--REFINED_BUCKET"      = aws_s3_bucket.layer["refined"].id
    "--YEARS"               = join(",", var.years)
    "--job-language"        = "python"
    "--job-bookmark-option" = "job-bookmark-disable"
  }
}

resource "aws_athena_workgroup" "crime" {
  name          = var.workgroup_name
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = var.query_cutoff_bytes

    result_configuration {
      output_location = "s3://${aws_s3_bucket.layer["refined"].id}/athena-results/"
    }
  }
}

resource "aws_iam_role" "lakeformation" {
  name = "eda262-g04-crime-av2-lakeformation"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lakeformation.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "lakeformation" {
  name = "ler-camadas"
  role = aws_iam_role.lakeformation.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = [for bucket in aws_s3_bucket.layer : "${bucket.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [for bucket in aws_s3_bucket.layer : bucket.arn]
      },
    ]
  })
}

resource "aws_lakeformation_resource" "layer" {
  for_each = aws_s3_bucket.layer
  arn      = each.value.arn
  role_arn = aws_iam_role.lakeformation.arn

  depends_on = [aws_iam_role_policy.lakeformation]
}

resource "aws_iam_policy" "consumer" {
  name = "eda262-g04-crime-av2-consulta"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["athena:StartQueryExecution", "athena:GetQueryExecution", "athena:GetQueryResults", "athena:StopQueryExecution", "athena:GetWorkGroup"]
        Resource = [aws_athena_workgroup.crime.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["glue:GetDatabase", "glue:GetDatabases", "glue:GetTable", "glue:GetTables", "glue:GetPartition", "glue:GetPartitions"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["lakeformation:GetDataAccess"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload"]
        Resource = ["${aws_s3_bucket.layer["refined"].arn}/athena-results/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.layer["refined"].arn]
      },
    ]
  })
}

resource "aws_iam_role" "consumer" {
  for_each = toset(["analyst", "manager"])
  name     = "eda262-g04-crime-av2-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "consumer" {
  for_each   = toset(["analyst", "manager"])
  role       = aws_iam_role.consumer[each.key].name
  policy_arn = aws_iam_policy.consumer.arn
}

resource "aws_lakeformation_permissions" "database" {
  for_each = {
    "analyst-trusted" = ["analyst", "trusted"]
    "analyst-refined" = ["analyst", "refined"]
    "manager-refined" = ["manager", "refined"]
  }
  principal   = aws_iam_role.consumer[each.value[0]].arn
  permissions = ["DESCRIBE"]
  database { name = aws_glue_catalog_database.layer[each.value[1]].name }
}

resource "aws_lakeformation_permissions" "analyst_trusted" {
  principal   = aws_iam_role.consumer["analyst"].arn
  permissions = ["SELECT", "DESCRIBE"]
  table {
    database_name = aws_glue_catalog_database.layer["trusted"].name
    name          = aws_glue_catalog_table.trusted.name
  }
}

resource "aws_lakeformation_permissions" "analyst_refined" {
  principal   = aws_iam_role.consumer["analyst"].arn
  permissions = ["SELECT", "DESCRIBE"]
  table {
    database_name = aws_glue_catalog_database.layer["refined"].name
    name          = aws_glue_catalog_table.refined.name
  }
}

resource "aws_lakeformation_permissions" "manager_refined" {
  principal   = aws_iam_role.consumer["manager"].arn
  permissions = ["SELECT", "DESCRIBE"]
  table {
    database_name = aws_glue_catalog_database.layer["refined"].name
    name          = aws_glue_catalog_table.refined.name
  }
}
