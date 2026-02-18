# ─── Project: Customers — Table Optimizers ───────────────────────
# Only Iceberg tables support optimizers.

module "optimizer_customers" {
  source = "../../modules/glue_table_optimizer"

  catalog_id    = var.account_id
  database_name = module.table_customers.database_name
  table_name    = module.table_customers.table_name
  role_arn      = var.table_optimizer_role_arn

  enable_compaction         = true
  enable_orphan_deletion    = true
  enable_snapshot_retention = true
}
