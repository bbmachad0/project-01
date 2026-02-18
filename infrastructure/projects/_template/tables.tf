# ─── Tables ──────────────────────────────────────────────────────
# Define Glue Data Catalog tables for this project.
#
# Convention:
#   - RAW layer    → table_format = "standard"  (Hive/Parquet)
#   - Refined      → table_format = "iceberg"
#   - Curated      → table_format = "iceberg"
#
# Example — Standard (Hive) table in the RAW layer:
#
#   module "table_raw_events" {
#     source = "../../modules/glue_catalog_table"
#
#     table_name    = "raw_events"
#     database_name = var.db_raw_name
#     catalog_id    = var.account_id
#     table_format  = "standard"
#     s3_location   = "s3://${var.raw_bucket}/<project_name>/raw_events/"
#     description   = "Raw ingested events — Parquet, as-is from source."
#
#     serde_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
#     input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
#     output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
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
#
# Example — Iceberg table in the Curated layer:
#
#   module "table_curated_summary" {
#     source = "../../modules/glue_catalog_table"
#
#     table_name    = "daily_summary"
#     database_name = var.db_curated_name
#     catalog_id    = var.account_id
#     table_format  = "iceberg"
#     s3_location   = "s3://${var.warehouse_bucket}/iceberg/${var.db_curated_name}/daily_summary"
#     description   = "Aggregated daily summaries — Iceberg."
#
#     columns = [
#       { name = "date",         type = "date",          comment = "Summary date" },
#       { name = "total_amount", type = "decimal(18,2)", comment = "Total amount" },
#       { name = "total_count",  type = "bigint",        comment = "Record count" },
#     ]
#   }
