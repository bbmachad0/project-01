# ─── Project: Legacy Refactor — Tables ───────────────────────────

# RAW layer — Standard (Hive/Parquet) table for legacy source data
module "table_raw_legacy_dump" {
  source = "../../modules/glue_catalog_table"

  table_name    = "raw_legacy_dump"
  database_name = var.db_raw_name
  catalog_id    = var.account_id
  table_format  = "standard"
  s3_location   = "s3://${var.raw_bucket}/legacy_refactor/raw_legacy_dump/"
  description   = "Legacy system data dump — Parquet, pre-schema-alignment."

  serde_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
  input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
  output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

  columns = [
    { name = "event_id", type = "string", comment = "Source event ID" },
    { name = "event_type", type = "string", comment = "Event type code" },
    { name = "payload", type = "string", comment = "JSON-encoded event payload" },
    { name = "source_ts", type = "string", comment = "Source timestamp (text — legacy)" },
  ]

  partition_keys = [
    { name = "dt", type = "string" },
  ]
}

# Refined layer — Iceberg table for schema-aligned events
module "table_legacy_events" {
  source = "../../modules/glue_catalog_table"

  table_name    = "legacy_events"
  database_name = var.db_refined_name
  catalog_id    = var.account_id
  table_format  = "iceberg"
  s3_location   = "s3://${var.warehouse_bucket}/iceberg/${var.db_refined_name}/legacy_events"
  description   = "Schema-aligned events from legacy ingestion — Iceberg."

  columns = [
    { name = "event_id", type = "string", comment = "Source event ID" },
    { name = "event_type", type = "string", comment = "Event type code" },
    { name = "payload", type = "string", comment = "JSON-encoded event payload" },
    { name = "ingested_at", type = "timestamp", comment = "Ingestion timestamp" },
  ]
}
