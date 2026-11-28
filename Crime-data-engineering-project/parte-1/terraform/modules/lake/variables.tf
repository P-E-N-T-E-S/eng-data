variable "bucket_name" {
  type = string
}

variable "database_name" {
  type = string
}

variable "table_name" {
  type = string
}

variable "workgroup_name" {
  type = string
}

variable "bytes_scanned_cutoff" {
  type = number
}

variable "anos" {
  type = list(string)
}
