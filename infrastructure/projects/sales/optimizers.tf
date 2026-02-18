# ─── Project: Sales — Table Optimizers ───────────────────────────
# Only Iceberg tables support optimizers.  Standard (Hive) tables
# like raw_sales_events are skipped.

module "optimizer_daily_sales" {
  source = "../../modules/glue_table_optimizer"

  catalog_id    = var.account_id
  database_name = module.table_daily_sales.database_name
  table_name    = module.table_daily_sales.table_name
  role_arn      = var.table_optimizer_role_arn

  enable_compaction         = true
  enable_orphan_deletion    = true
  enable_snapshot_retention = true
}
