variable "region" {
  type        = string
  description = "Região AWS da entrega."
  default     = "us-east-1"
}

variable "raw_bucket_name" {
  type    = string
  default = "eda262-g04-lake-raw"
}

variable "trusted_bucket_name" {
  type    = string
  default = "eda262-g04-lake-trusted"
}

variable "refined_bucket_name" {
  type    = string
  default = "eda262-g04-lake-refined"
}

variable "workgroup_name" {
  type    = string
  default = "eda262-g04-crime-av2-wg"
}

variable "years" {
  type    = list(string)
  default = ["2024", "2025", "2026"]

  validation {
    condition     = length(var.years) > 0 && alltrue([for year in var.years : can(regex("^20[0-9]{2}$", year))])
    error_message = "years deve conter anos no formato AAAA."
  }
}

variable "query_target_bytes" {
  type        = number
  description = "Meta de varredura da consulta anual na refined."
  default     = 1048576
}

variable "query_cutoff_bytes" {
  type        = number
  description = "Teto do workgroup. O Athena exige no mínimo 10 MiB."
  default     = 10485760
}

variable "import_existing_trusted_bucket" {
  type        = bool
  description = "Use somente durante a migração incremental da AV1 já implantada."
  default     = false
}
