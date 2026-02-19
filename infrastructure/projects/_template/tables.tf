# --- Tables -----------------------------------------------------------
# Define Glue Data Catalog tables for this project.
#
# Two modules available:
#   glue_iceberg_table  -> Iceberg table + 3 optimizers (plug-and-play)
#   glue_catalog_table  -> Standard Hive/Parquet table (no optimizers)
#
# Iceberg: S3 path is auto-derived from table_name:
#   s3://{bucket}/{project_slug}/{database}/{table_name}
#
# Example - Iceberg table in the Curated layer:
#
#   module "table_curated_summary" {
#     source = "../../modules/glue_iceberg_table"
#
#     table_name         = "daily_summary"
#     database_name      = var.db_curated_name
#     catalog_id         = var.account_id
#     project_slug       = var.project_slug
#     bucket             = var.curated_bucket
#     optimizer_role_arn = module.iam_table_optimizer.role_arn
#     description        = "Aggregated daily summaries - Iceberg."
#
#     columns = [
#       { name = "date",         type = "date",          comment = "Summary date" },
#       { name = "total_amount", type = "decimal(18,2)", comment = "Total amount" },
#       { name = "total_count",  type = "bigint",        comment = "Record count" },
#     ]
#   }
#
# Example - Standard (Hive/Parquet) table in the RAW layer:
#
#   module "table_raw_events" {
#     source = "../../modules/glue_catalog_table"
#
#     table_name    = "raw_events"
#     database_name = var.db_raw_name
#     catalog_id    = var.account_id
#     s3_location   = "s3://${var.raw_bucket}/${var.project_slug}/raw_events/"
#     description   = "Raw ingested events - Parquet, as-is from source."
#
#     columns = [
#       { name = "event_id",   type = "string",    comment = "Unique event identifier" },
#       { name = "payload",    type = "string",    comment = "JSON payload" },
#       { name = "created_at", type = "timestamp", comment = "Event timestamp" },
#     ]
#
#     partition_keys = [
#       { name = "dt", type = "string" },
#     ]
#   }
