# ─── Glue Catalog Table Module ───────────────────────────────────
# Creates a Glue Data Catalog table.  Supports two formats:
#
#   iceberg  - Apache Iceberg (open_table_format_input + Iceberg params)
#   standard - Classic Hive-style external table (SerDe, input/output format)
#
# For Iceberg tables managed entirely by Spark jobs at runtime, you
# may omit this module - Spark CREATE TABLE statements also register
# in the Glue Catalog.  This module is useful when you want Terraform
# to own the table definition for governance and drift detection.

# ─── Variables ───────────────────────────────────────────────────

variable "table_name" {
  description = "Name of the Glue Catalog table."
  type        = string
}

variable "database_name" {
  description = "Glue Catalog database the table belongs to."
  type        = string
}

variable "catalog_id" {
  description = "AWS account ID (Glue Catalog ID)."
  type        = string
  default     = null
}

variable "description" {
  description = "Table description."
  type        = string
  default     = ""
}

variable "table_format" {
  description = "Table format: 'iceberg' or 'standard'."
  type        = string
  default     = "iceberg"

  validation {
    condition     = contains(["iceberg", "standard"], var.table_format)
    error_message = "table_format must be 'iceberg' or 'standard'."
  }
}

variable "s3_location" {
  description = "S3 location for table data."
  type        = string
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

variable "partition_keys" {
  description = "Partition key definitions (standard tables only; Iceberg uses hidden partitioning)."
  type = list(object({
    name = string
    type = string
  }))
  default = []
}

variable "table_type" {
  description = "Hive table type: EXTERNAL_TABLE, VIRTUAL_VIEW, etc."
  type        = string
  default     = "EXTERNAL_TABLE"
}

variable "serde_library" {
  description = "SerDe serialization library class (standard tables)."
  type        = string
  default     = ""
}

variable "input_format" {
  description = "Hadoop InputFormat class (standard tables)."
  type        = string
  default     = ""
}

variable "output_format" {
  description = "Hadoop OutputFormat class (standard tables)."
  type        = string
  default     = ""
}

variable "table_parameters" {
  description = "Additional key-value parameters for the table."
  type        = map(string)
  default     = {}
}

# ─── Locals ──────────────────────────────────────────────────────

locals {
  iceberg_parameters = {
    "table_type"     = "ICEBERG"
    "classification" = "iceberg"
  }

  final_parameters = (
    var.table_format == "iceberg"
    ? merge(local.iceberg_parameters, var.table_parameters)
    : var.table_parameters
  )
}

# ─── Resource ────────────────────────────────────────────────────

resource "aws_glue_catalog_table" "this" {
  name          = var.table_name
  database_name = var.database_name
  catalog_id    = var.catalog_id
  description   = var.description
  table_type    = var.table_type
  parameters    = local.final_parameters

  # ── Iceberg open-table-format input ────────────────────────────
  dynamic "open_table_format_input" {
    for_each = var.table_format == "iceberg" ? [1] : []
    content {
      iceberg_input {
        metadata_operation = "CREATE"
        version            = "2"
      }
    }
  }

  # ── Storage descriptor ─────────────────────────────────────────
  storage_descriptor {
    location = var.s3_location

    dynamic "columns" {
      for_each = var.columns
      content {
        name    = columns.value.name
        type    = columns.value.type
        comment = columns.value.comment
      }
    }

    # Standard tables - SerDe info
    dynamic "ser_de_info" {
      for_each = var.table_format == "standard" && var.serde_library != "" ? [1] : []
      content {
        serialization_library = var.serde_library
      }
    }

    input_format  = var.table_format == "standard" && var.input_format != "" ? var.input_format : null
    output_format = var.table_format == "standard" && var.output_format != "" ? var.output_format : null
  }

  # ── Partition keys (standard tables only) ──────────────────────
  dynamic "partition_keys" {
    for_each = var.table_format == "standard" ? var.partition_keys : []
    content {
      name = partition_keys.value.name
      type = partition_keys.value.type
    }
  }
}

# ─── Outputs ─────────────────────────────────────────────────────

output "table_name" {
  description = "Name of the created table."
  value       = aws_glue_catalog_table.this.name
}

output "table_arn" {
  description = "ARN of the created table."
  value       = aws_glue_catalog_table.this.arn
}

output "database_name" {
  description = "Database the table belongs to."
  value       = aws_glue_catalog_table.this.database_name
}
