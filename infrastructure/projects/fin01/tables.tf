module "table_curated_teste" {
  source = "../../modules/glue_catalog_table"

  table_name    = "teste"
  database_name = var.db_curated_name
  catalog_id    = var.account_id
  table_format  = "iceberg"
  s3_location   = "s3://${var.warehouse_bucket}/iceberg/${var.db_curated_name}/teste"
  description   = "Tabela teste - Iceberg."

  columns = [
    { name = "id",         type = "string",    comment = "ID" },
    { name = "value",      type = "string",    comment = "Valor" },
    { name = "created_at", type = "timestamp", comment = "Data criação" },
  ]
}