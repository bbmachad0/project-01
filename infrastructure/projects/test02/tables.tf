# ── RAW: tabela padrão (Hive/Parquet) com partição por year/month/day ──

module "table_raw_events" {
  source = "../../modules/glue_catalog_table"

  table_name    = "events"
  database_name = local.foundation.db_raw_name
  catalog_id    = data.aws_caller_identity.current.account_id
  s3_location   = "s3://${local.foundation.s3_raw_bucket_id}/${local.config.slug}/events/"
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
  database_name      = local.foundation.db_refined_name
  catalog_id         = data.aws_caller_identity.current.account_id
  project_slug       = local.config.slug
  bucket             = local.foundation.s3_refined_bucket_id
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
  database_name      = local.foundation.db_curated_name
  catalog_id         = data.aws_caller_identity.current.account_id
  project_slug       = local.config.slug
  bucket             = local.foundation.s3_curated_bucket_id
  optimizer_role_arn = module.iam_table_optimizer.role_arn
  description        = "Resumo agregado - Iceberg."

  columns = [
    { name = "date",    type = "date",          comment = "Data de referência" },
    { name = "total",   type = "decimal(18,2)", comment = "Total agregado" },
    { name = "count",   type = "bigint",        comment = "Contagem de registros" },
  ]
}
