# ─── Glue Job Module ─────────────────────────────────────────────
# Reusable Terraform module to provision a single AWS Glue job.
#
# Supports:
#   - Spark (Glue 5.1) and Python Shell job types
#   - Configurable DPU / worker allocation
#   - Extra Python libraries via .whl on S3
#   - Job bookmarks, metrics, and observability defaults

variable "job_name" {
  description = "Human-readable Glue job name."
  type        = string
}

variable "description" {
  description = "Optional description of the job."
  type        = string
  default     = ""
}

variable "role_arn" {
  description = "IAM role ARN the Glue job assumes at runtime."
  type        = string
}

variable "script_s3_path" {
  description = "S3 URI of the job script (e.g. s3://bucket/jobs/sales/job_daily_sales.py)."
  type        = string
}

variable "extra_py_files" {
  description = "Comma-separated S3 URIs of additional Python files or wheels."
  type        = string
  default     = ""
}

variable "glue_version" {
  description = "Glue runtime version."
  type        = string
  default     = "5.0"
}

variable "worker_type" {
  description = "Glue worker type: Standard | G.1X | G.2X | G.4X | G.8X | Z.2X."
  type        = string
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Number of Glue workers (DPUs)."
  type        = number
  default     = 2
}

variable "max_retries" {
  description = "Maximum number of automatic retries on failure."
  type        = number
  default     = 1
}

variable "timeout_minutes" {
  description = "Job timeout in minutes."
  type        = number
  default     = 120
}

variable "default_arguments" {
  description = "Map of default arguments passed to the job."
  type        = map(string)
  default     = {}
}

variable "connections" {
  description = "List of Glue connection names (VPC connectivity)."
  type        = list(string)
  default     = []
}

variable "enable_metrics" {
  description = "Enable Spark UI and CloudWatch metrics."
  type        = bool
  default     = true
}

variable "bookmark_enabled" {
  description = "Enable job bookmarks for incremental processing."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

# ─── Locals ──────────────────────────────────────────────────────

locals {
  base_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = var.enable_metrics ? "true" : "false"
    "--enable-spark-ui"                  = var.enable_metrics ? "true" : "false"
    "--enable-glue-datacatalog"          = "true"
    "--job-bookmark-option"              = var.bookmark_enabled ? "job-bookmark-enable" : "job-bookmark-disable"
    "--TempDir"                          = "s3://${var.tags["project"]}-artifacts-${var.tags["env"]}/glue-temp/"
    "--extra-py-files"                   = var.extra_py_files
    "--datalake-formats"                 = "iceberg"
    "--conf"                             = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions --conf spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog --conf spark.sql.catalog.glue_catalog.warehouse=s3://${var.tags["project"]}-warehouse-${var.tags["env"]}/iceberg/"
  }

  merged_arguments = merge(local.base_arguments, var.default_arguments)
}

# ─── Resource ────────────────────────────────────────────────────

resource "aws_glue_job" "this" {
  name        = var.job_name
  description = var.description
  role_arn    = var.role_arn

  glue_version      = var.glue_version
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  max_retries       = var.max_retries
  timeout           = var.timeout_minutes

  command {
    name            = "glueetl"
    script_location = var.script_s3_path
    python_version  = "3"
  }

  default_arguments = local.merged_arguments

  dynamic "connections" {
    for_each = length(var.connections) > 0 ? [1] : []
    content {
      connections = var.connections
    }
  }

  tags = var.tags
}

# ─── Outputs ─────────────────────────────────────────────────────

output "job_name" {
  value = aws_glue_job.this.name
}

output "job_arn" {
  value = aws_glue_job.this.arn
}
