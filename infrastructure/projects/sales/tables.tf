# ─── Project: Sales — Tables ─────────────────────────────────────

# RAW layer — Standard (Hive/Parquet) table for ingested sales events
module "table_raw_sales_events" {
  source = "../../modules/glue_catalog_table"

  table_name    = "raw_sales_events"
  database_name = var.db_raw_name
  catalog_id    = var.account_id
  table_format  = "standard"
  s3_location   = "s3://${var.raw_bucket}/sales/raw_sales_events/"
  description   = "Raw ingested sales events — Parquet, as-is from source."

  serde_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
  input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
  output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

  columns = [
    { name = "event_id", type = "string", comment = "Unique event identifier" },
    { name = "store_id", type = "string", comment = "Store identifier" },
    { name = "product_id", type = "string", comment = "Product identifier" },
    { name = "quantity", type = "int", comment = "Quantity sold" },
    { name = "amount", type = "decimal(18,2)", comment = "Sale amount" },
    { name = "event_timestamp", type = "timestamp", comment = "Event timestamp" },
  ]

  partition_keys = [
    { name = "dt", type = "string" },
  ]
}

# Curated layer — Iceberg table for aggregated daily sales
module "table_daily_sales" {
  source = "../../modules/glue_catalog_table"

  table_name    = "daily_sales"
  database_name = var.db_curated_name
  catalog_id    = var.account_id
  table_format  = "iceberg"
  s3_location   = "s3://${var.warehouse_bucket}/iceberg/${var.db_curated_name}/daily_sales"
  description   = "Aggregated daily sales summaries — Iceberg."

  columns = [
    { name = "sale_date", type = "date", comment = "Aggregation date" },
    { name = "region", type = "string", comment = "Sales region" },
    { name = "total_amount", type = "decimal(18,2)", comment = "Total sales amount" },
    { name = "total_orders", type = "bigint", comment = "Number of orders" },
  ]
}
