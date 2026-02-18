# ─── Project: Customers — Tables ─────────────────────────────────

# RAW layer — Standard (Hive/Parquet) table for CDC events
module "table_raw_customer_cdc" {
  source = "../../modules/glue_catalog_table"

  table_name    = "raw_customer_cdc"
  database_name = var.db_raw_name
  catalog_id    = var.account_id
  table_format  = "standard"
  s3_location   = "s3://${var.raw_bucket}/customers/raw_customer_cdc/"
  description   = "Raw CDC events from customer source — Parquet."

  serde_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
  input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
  output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

  columns = [
    { name = "customer_id", type = "string", comment = "Unique customer identifier" },
    { name = "name", type = "string", comment = "Full name" },
    { name = "email", type = "string", comment = "Contact email" },
    { name = "status", type = "string", comment = "Account status" },
    { name = "op", type = "string", comment = "CDC operation (I/U/D)" },
    { name = "cdc_timestamp", type = "timestamp", comment = "CDC event timestamp" },
  ]

  partition_keys = [
    { name = "dt", type = "string" },
  ]
}

# Curated layer — Iceberg table for merged customer master
module "table_customers" {
  source = "../../modules/glue_catalog_table"

  table_name    = "customers"
  database_name = var.db_curated_name
  catalog_id    = var.account_id
  table_format  = "iceberg"
  s3_location   = "s3://${var.warehouse_bucket}/iceberg/${var.db_curated_name}/customers"
  description   = "Customer master data with CDC merge — Iceberg."

  columns = [
    { name = "customer_id", type = "string", comment = "Unique customer identifier" },
    { name = "name", type = "string", comment = "Full name" },
    { name = "email", type = "string", comment = "Contact email" },
    { name = "status", type = "string", comment = "Account status" },
    { name = "updated_at", type = "timestamp", comment = "Last CDC timestamp" },
  ]
}
