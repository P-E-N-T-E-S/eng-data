# Migração incremental da AV1. Os blocos são idempotentes após a importação e
# documentam que o bucket trusted é preservado entre as duas partes.
import {
  for_each = var.import_existing_trusted_bucket ? toset(["trusted"]) : toset([])
  to       = module.platform.aws_s3_bucket.layer[each.key]
  id       = var.trusted_bucket_name
}

import {
  for_each = var.import_existing_trusted_bucket ? toset(["trusted"]) : toset([])
  to       = module.platform.aws_s3_bucket_public_access_block.layer[each.key]
  id       = var.trusted_bucket_name
}

import {
  for_each = var.import_existing_trusted_bucket ? toset(["trusted"]) : toset([])
  to       = module.platform.aws_s3_bucket_server_side_encryption_configuration.layer[each.key]
  id       = var.trusted_bucket_name
}

import {
  for_each = var.import_existing_trusted_bucket ? toset(["trusted"]) : toset([])
  to       = module.platform.aws_s3_bucket_versioning.layer[each.key]
  id       = var.trusted_bucket_name
}
