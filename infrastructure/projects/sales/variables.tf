# ─── Project: Sales — Variables ──────────────────────────────────

variable "domain_abbr" {
  type = string
}

variable "project_slug" {
  type = string
}

variable "env" {
  type = string
}

variable "account_id" {
  type = string
}

variable "artifacts_bucket" {
  type = string
}

variable "raw_bucket" {
  type = string
}

variable "curated_bucket" {
  type = string
}

variable "warehouse_bucket" {
  type = string
}

variable "glue_execution_role_arn" {
  type = string
}

variable "table_optimizer_role_arn" {
  type = string
}

variable "sfn_execution_role_arn" {
  type = string
}

variable "db_raw_name" {
  type = string
}

variable "db_refined_name" {
  type = string
}

variable "db_curated_name" {
  type = string
}

variable "common_tags" {
  type = map(string)
}
