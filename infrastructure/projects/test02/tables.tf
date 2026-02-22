# ── RAW: tabela padrão (Hive/Parquet) com partição por year/month/day ──

module "table_raw_events" {
  source = "../../modules/glue_catalog_table"

  table_name    = "events"
  database_name = var.db_raw_name
  catalog_id    = var.account_id
  s3_location   = "s3://${var.raw_bucket}/${var.project_slug}/events/"
  description   = "Raw events - Parquet particionado por data."

  columns = [
    { name = "id",         type = "string",    comment = "Identificador único" },
    { name = "payload",    type = "string",    comment = "Payload JSON" },
    { name = "created_at", type = "timestamp", comment = "Timestamp do evento" },
  ]

  partition_keys = [
    { name = "year",  type = "string" },
    { name = "month", type = "string" },
    { name = "day",   type = "string" },
  ]
}

# ── REFINED: Iceberg (optimizers incluídos automaticamente) ──

module "table_refined_events" {
  source = "../../modules/glue_iceberg_table"

  table_name         = "events"
  database_name      = var.db_refined_name
  catalog_id         = var.account_id
  project_slug       = var.project_slug
  bucket             = var.refined_bucket
  optimizer_role_arn = module.iam_table_optimizer.role_arn
  description        = "Events conformados - Iceberg."

  columns = [
    { name = "id",         type = "string",    comment = "Identificador único" },
    { name = "payload",    type = "string",    comment = "Payload JSON" },
    { name = "created_at", type = "timestamp", comment = "Timestamp do evento" },
  ]
}

# ── CURATED: Iceberg (optimizers incluídos automaticamente) ──

module "table_curated_summary" {
  source = "../../modules/glue_iceberg_table"

  table_name         = "summary"
  database_name      = var.db_curated_name
  catalog_id         = var.account_id
  project_slug       = var.project_slug
  bucket             = var.curated_bucket
  optimizer_role_arn = module.iam_table_optimizer.role_arn
  description        = "Resumo agregado - Iceberg."

  columns = [
    { name = "date",    type = "date",          comment = "Data de referência" },
    { name = "total",   type = "decimal(18,2)", comment = "Total agregado" },
    { name = "count",   type = "bigint",        comment = "Contagem de registros" },
  ]
}
