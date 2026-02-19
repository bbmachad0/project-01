# ─── Glue Iceberg Table Module ───────────────────────────────────
# Creates an Iceberg table in the Glue Data Catalog AND its three
# mandatory optimizers (compaction, retention, orphan file deletion).
#
# Plug-and-play: specify `table_name` once and everything else
# (S3 location, optimizer references) is auto-derived.
#
# S3 layout:  s3://{warehouse_bucket}/{project_slug}/{database_name}/{table_name}/
#
# Resource: aws_glue_catalog_table + 3x aws_glue_catalog_table_optimizer

# ─── Variables ───────────────────────────────────────────────────

variable "table_name" {
  description = "Name of the Iceberg table (e.g. daily_summary)."
  type        = string
}

variable "database_name" {
  description = "Glue Catalog database the table belongs to."
  type        = string
}

variable "catalog_id" {
  description = "AWS account ID (Glue Catalog ID)."
  type        = string
}

variable "project_slug" {
  description = "Project slug - used to build the S3 prefix ({bucket}/{project_slug}/...)."
  type        = string
}

variable "warehouse_bucket" {
  description = "S3 bucket ID for the Iceberg warehouse."
  type        = string
}

variable "optimizer_role_arn" {
  description = "IAM role ARN for the table optimizer service."
  type        = string
}

variable "description" {
  description = "Table description."
  type        = string
  default     = ""
}

variable "columns" {
  description = "List of column definitions: [{name, type, comment}]."
  type = list(object({
    name    = string
    type    = string
    comment = optional(string, "")
  }))
  default = []
}

variable "table_parameters" {
  description = "Additional key-value parameters for the table."
  type        = map(string)
  default     = {}
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

# ─── Locals ──────────────────────────────────────────────────────

locals {
  # Single source of truth for the S3 location of this table.
  s3_location = "s3://${var.warehouse_bucket}/${var.project_slug}/${var.database_name}/${var.table_name}"

  # NOTE: Do NOT include "table_type" or "metadata_location" here.
  # These are reserved parameters managed automatically by the Glue API
  # when open_table_format_input.iceberg_input is used.
  iceberg_parameters = {
    "classification" = "iceberg"
  }

  # Strip reserved keys that Glue manages automatically for Iceberg tables.
  safe_extra = { for k, v in var.table_parameters : k => v if !contains(["table_type", "metadata_location"], k) }

  final_parameters = merge(local.iceberg_parameters, local.safe_extra)
}

# ─── Iceberg Table ───────────────────────────────────────────────

resource "aws_glue_catalog_table" "this" {
  name          = var.table_name
  database_name = var.database_name
  catalog_id    = var.catalog_id
  description   = var.description
  table_type    = "EXTERNAL_TABLE"
  parameters    = local.final_parameters

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
      version            = "2"
    }
  }

  storage_descriptor {
    location = local.s3_location

    dynamic "columns" {
      for_each = var.columns
      content {
        name    = columns.value.name
        type    = columns.value.type
        comment = columns.value.comment
      }
    }
  }
}

# ─── Optimizer: Compaction ───────────────────────────────────────

resource "aws_glue_catalog_table_optimizer" "compaction" {
  catalog_id    = var.catalog_id
  database_name = aws_glue_catalog_table.this.database_name
  table_name    = aws_glue_catalog_table.this.name
  type          = "compaction"

  configuration {
    role_arn = var.optimizer_role_arn
    enabled  = true
  }
}

# ─── Optimizer: Snapshot Retention ───────────────────────────────

resource "aws_glue_catalog_table_optimizer" "retention" {
  catalog_id    = var.catalog_id
  database_name = aws_glue_catalog_table.this.database_name
  table_name    = aws_glue_catalog_table.this.name
  type          = "retention"

  configuration {
    role_arn = var.optimizer_role_arn
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

# ─── Optimizer: Orphan File Deletion ─────────────────────────────

resource "aws_glue_catalog_table_optimizer" "orphan_file_deletion" {
  catalog_id    = var.catalog_id
  database_name = aws_glue_catalog_table.this.database_name
  table_name    = aws_glue_catalog_table.this.name
  type          = "orphan_file_deletion"

  configuration {
    role_arn = var.optimizer_role_arn
    enabled  = true

    orphan_file_deletion_configuration {
      iceberg_configuration {
        orphan_file_retention_period_in_days = var.orphan_file_retention_days
        location                             = local.s3_location
      }
    }
  }
}

# ─── Outputs ─────────────────────────────────────────────────────

output "table_name" {
  description = "Name of the Iceberg table."
  value       = aws_glue_catalog_table.this.name
}

output "table_arn" {
  description = "ARN of the Iceberg table."
  value       = aws_glue_catalog_table.this.arn
}

output "database_name" {
  description = "Database the table belongs to."
  value       = aws_glue_catalog_table.this.database_name
}

output "s3_location" {
  description = "S3 location of the Iceberg table data."
  value       = local.s3_location
}
