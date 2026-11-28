variable "raw_bucket_name" { type = string }
variable "trusted_bucket_name" { type = string }
variable "refined_bucket_name" { type = string }
variable "workgroup_name" { type = string }
variable "years" { type = list(string) }
variable "query_target_bytes" { type = number }
variable "query_cutoff_bytes" { type = number }
