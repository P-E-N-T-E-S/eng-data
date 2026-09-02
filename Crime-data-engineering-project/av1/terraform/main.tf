# ============================================================================
# AV1 — Data Lake Crime Brasil (grupo g04)
# Schema DECLARADO (sem AWS::Glue::Crawler). Idem ao template da Aula 04,
# so que em Terraform e com o dataset BancoVDE (CSV, particionado por ano).
# ============================================================================

# ---------- 1. Bucket trusted (camada trusted fica em CSV na AV1) ----------
resource "aws_s3_bucket" "trusted" {
  bucket = var.bucket_name
  tags = {
    Disciplina = "EDA"
    Turma      = "2026-2"
    Grupo      = "g04"
    Owner      = var.owner
  }
}

resource "aws_s3_bucket_versioning" "trusted" {
  bucket = aws_s3_bucket.trusted.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trusted" {
  bucket = aws_s3_bucket.trusted.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "trusted" {
  bucket                  = aws_s3_bucket.trusted.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- 2. Glue Data Catalog: database ----------
resource "aws_glue_catalog_database" "crime" {
  name = var.database_name
}

# ---------- 3. Glue Data Catalog: tabela DECLARADA (sem crawler) ----------
resource "aws_glue_catalog_table" "crime_trusted" {
  name          = var.table_name
  database_name = aws_glue_catalog_database.crime.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification"         = "csv"
    "skip.header.line.count" = "1"
  }

  # Chave de particao: ano (1 CSV por ano).
  partition_keys {
    name = "ano"
    type = "int"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.trusted.bucket}/crime/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "csv-serde"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"            = ","
        "serialization.format"   = ","
        "skip.header.line.count" = "1"
      }
    }

    # 14 colunas originais + ano + mes = 16 (declaradas, sem crawler).
    dynamic "columns" {
      for_each = local.colunas
      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }
}

# ---------- 4. Particoes declaradas (ano=2024/2025/2026) ----------
resource "aws_glue_partition" "ano" {
  for_each      = toset(var.anos)
  database_name = aws_glue_catalog_database.crime.name
  table_name    = aws_glue_catalog_table.crime_trusted.name
  values        = [each.value]

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.trusted.bucket}/crime/ano=${each.value}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "csv-serde"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"            = ","
        "serialization.format"   = ","
        "skip.header.line.count" = "1"
      }
    }

    dynamic "columns" {
      for_each = local.colunas
      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }
}

# ---------- 5. Athena workgroup (teto calculado, DECISAO 05) ----------
resource "aws_athena_workgroup" "crime" {
  name = var.workgroup_name
  state = "ENABLED"

  configuration {
    bytes_scanned_cutoff_per_query   = var.bytes_scanned_cutoff
    enforce_workgroup_configuration  = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.trusted.bucket}/athena-results/"
    }
  }

  tags = {
    Disciplina = "EDA"
    Turma      = "2026-2"
    Grupo      = "g04"
    Owner      = var.owner
  }
}
