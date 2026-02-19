# ─── Glue Catalog Table Optimizer Module ─────────────────────────
# Provisions the three Iceberg table maintenance optimizers
# available in AWS Glue:
#
#   compaction           - merges small files to improve query performance
#   orphan_file_deletion - removes unreferenced data files
#   retention            - expires old Iceberg snapshots
#
# Every Iceberg table MUST have all three.  Standard (Hive) tables
# do NOT support optimizers - do not call this module for them.
#
# Resource: aws_glue_catalog_table_optimizer
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_table_optimizer

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

variable "s3_location" {
  description = "S3 location of the Iceberg table data (for orphan file deletion)."
  type        = string
}

variable "snapshot_retention_days" {
  description = "Number of days to retain Iceberg snapshots."
  type        = number
  default     = 7
}

variable "snapshots_to_retain" {
  description = "Minimum number of snapshots to keep regardless of age."
  type        = number
  default     = 3
}

variable "clean_expired_files" {
  description = "Whether to delete data files referenced only by expired snapshots."
  type        = bool
  default     = true
}

variable "orphan_file_retention_days" {
  description = "Number of days before an orphan file is eligible for deletion."
  type        = number
  default     = 7
}

# ─── Resources ───────────────────────────────────────────────────

# 1. Compaction - merges small files into larger ones.

resource "aws_glue_catalog_table_optimizer" "compaction" {
  catalog_id    = var.catalog_id
  database_name = var.database_name
  table_name    = var.table_name
  type          = "compaction"

  configuration {
    role_arn = var.role_arn
    enabled  = true
  }
}

# 2. Snapshot Retention - expires old Iceberg snapshots.

resource "aws_glue_catalog_table_optimizer" "retention" {
  catalog_id    = var.catalog_id
  database_name = var.database_name
  table_name    = var.table_name
  type          = "retention"

  configuration {
    role_arn = var.role_arn
    enabled  = true

    retention_configuration {
      iceberg_configuration {
        snapshot_retention_period_in_days = var.snapshot_retention_days
        number_of_snapshots_to_retain     = var.snapshots_to_retain
        clean_expired_files               = var.clean_expired_files
      }
    }
  }
}

# 3. Orphan File Deletion - removes unreferenced data files.

resource "aws_glue_catalog_table_optimizer" "orphan_file_deletion" {
  catalog_id    = var.catalog_id
  database_name = var.database_name
  table_name    = var.table_name
  type          = "orphan_file_deletion"

  configuration {
    role_arn = var.role_arn
    enabled  = true

    orphan_file_deletion_configuration {
      iceberg_configuration {
        orphan_file_retention_period_in_days = var.orphan_file_retention_days
        location                             = var.s3_location
      }
    }
  }
}
