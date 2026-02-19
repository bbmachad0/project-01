# ─── Glue Standard Table Module ──────────────────────────────────
# Creates a standard (Hive) Glue Data Catalog table.
#
# For Iceberg tables, use the glue_iceberg_table module instead -
# it bundles the table with its three mandatory optimizers.
#
# This module is for RAW-layer or other non-Iceberg external tables
# that use classic SerDe, InputFormat, and OutputFormat.

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
  description = "Partition key definitions."
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
  description = "SerDe serialization library class."
  type        = string
  default     = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
}

variable "input_format" {
  description = "Hadoop InputFormat class."
  type        = string
  default     = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
}

variable "output_format" {
  description = "Hadoop OutputFormat class."
  type        = string
  default     = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
}

variable "table_parameters" {
  description = "Additional key-value parameters for the table."
  type        = map(string)
  default     = {}
}

# ─── Resource ────────────────────────────────────────────────────

resource "aws_glue_catalog_table" "this" {
  name          = var.table_name
  database_name = var.database_name
  catalog_id    = var.catalog_id
  description   = var.description
  table_type    = var.table_type
  parameters    = var.table_parameters

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

    ser_de_info {
      serialization_library = var.serde_library
    }

    input_format  = var.input_format
    output_format = var.output_format
  }

  dynamic "partition_keys" {
    for_each = var.partition_keys
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
