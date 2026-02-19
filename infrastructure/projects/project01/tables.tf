# ─── Iceberg Tables ──────────────────────────────────────────────
# Each module call creates the Iceberg table + 3 optimizers
# (compaction, retention, orphan_file_deletion) automatically.
#
# S3 path is auto-derived: s3://{bucket}/{project_slug}/{database}/{table_name}

module "table_curated_teste" {
  source = "../../modules/glue_iceberg_table"

  table_name         = "teste"
  database_name      = var.db_curated_name
  catalog_id         = var.account_id
  project_slug       = var.project_slug
  bucket             = var.curated_bucket
  optimizer_role_arn = module.iam_table_optimizer.role_arn
  description        = "Tabela teste - Iceberg."

  columns = [
    { name = "id", type = "string", comment = "ID" },
    { name = "value", type = "string", comment = "Valor" },
    { name = "created_at", type = "timestamp", comment = "Data de criacao" },
  ]
}