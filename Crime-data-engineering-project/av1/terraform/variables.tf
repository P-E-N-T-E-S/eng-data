variable "region" {
  description = "Regiao AWS (us-east-1 para ficar perto da conta da disciplina)."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "E-mail institucional para a tag Owner."
  type        = string
  default     = "egcf@cesar.school"
}

variable "bucket_name" {
  description = "Nome do bucket trusted (unico globalmente)."
  type        = string
  default     = "eda262-g04-lake-trusted"
}

variable "database_name" {
  description = "Nome do database no Glue Data Catalog (underscore, nao hifen)."
  type        = string
  default     = "eda262_g04_crime_db"
}

variable "table_name" {
  description = "Nome da tabela declarada (sem crawler)."
  type        = string
  default     = "crime_trusted"
}

variable "workgroup_name" {
  description = "Nome do workgroup do Athena."
  type        = string
  default     = "eda262-g04-crime-wg"
}

variable "bytes_scanned_cutoff" {
  description = "Teto de bytes por consulta (DECISAO 05). ~400MB mata a larga e deixa a certa."
  type        = number
  default     = 419430400 # 400 MB
}

variable "anos" {
  description = "Particoes de ano a declarar (1 CSV por ano)."
  type        = list(string)
  default     = ["2024", "2025", "2026"]
}
