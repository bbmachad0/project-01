# ─── Glue Table Optimizer Module ─────────────────────────────────
# Provisions the three Iceberg table maintenance optimizers
# available in AWS Glue:
#
#   compaction          - merges small files to improve query performance
#   orphan_file_deletion - removes unreferenced data files
#   retention           - expires old Iceberg snapshots
#
# Each optimizer can be independently enabled / disabled per table.

# ─── Variables ───────────────────────────────────────────────────

variable "catalog_id" {
  description = "AWS account ID (Glue Catalog ID)."
  type        = string
}

variable "database_name" {
  description = "Glue Catalog database name."
  type        = string
}

variable "table_name" {
  description = "Glue Catalog table name."
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN that the optimizer service assumes."
  type        = string
}

variable "enable_compaction" {
  description = "Enable Iceberg auto-compaction."
  type        = bool
  default     = true
}

variable "enable_orphan_deletion" {
  description = "Enable orphan file deletion."
  type        = bool
  default     = true
}

variable "enable_snapshot_retention" {
  description = "Enable snapshot retention (expired snapshot cleanup)."
  type        = bool
  default     = true
}

# ─── Resources ───────────────────────────────────────────────────

resource "aws_glue_table_optimizer" "compaction" {
  count = var.enable_compaction ? 1 : 0

  catalog_id    = var.catalog_id
  database_name = var.database_name
  table_name    = var.table_name
  type          = "compaction"

  configuration {
    role_arn = var.role_arn
    enabled  = true
  }
}

resource "aws_glue_table_optimizer" "orphan_file_deletion" {
  count = var.enable_orphan_deletion ? 1 : 0

  catalog_id    = var.catalog_id
  database_name = var.database_name
  table_name    = var.table_name
  type          = "orphan_file_deletion"

  configuration {
    role_arn = var.role_arn
    enabled  = true
  }
}

resource "aws_glue_table_optimizer" "snapshot_retention" {
  count = var.enable_snapshot_retention ? 1 : 0

  catalog_id    = var.catalog_id
  database_name = var.database_name
  table_name    = var.table_name
  type          = "retention"

  configuration {
    role_arn = var.role_arn
    enabled  = true
  }
}

# ─── Outputs ─────────────────────────────────────────────────────

output "compaction_enabled" {
  description = "Whether compaction optimizer was created."
  value       = var.enable_compaction
}

output "orphan_deletion_enabled" {
  description = "Whether orphan file deletion optimizer was created."
  value       = var.enable_orphan_deletion
}

output "snapshot_retention_enabled" {
  description = "Whether snapshot retention optimizer was created."
  value       = var.enable_snapshot_retention
}
