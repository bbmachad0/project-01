# ─── Project: Legacy Refactor — Table Optimizers ─────────────────
# Only the Iceberg table (legacy_events) gets optimizers.

module "optimizer_legacy_events" {
  source = "../../modules/glue_table_optimizer"

  catalog_id    = var.account_id
  database_name = module.table_legacy_events.database_name
  table_name    = module.table_legacy_events.table_name
  role_arn      = var.table_optimizer_role_arn

  enable_compaction         = true
  enable_orphan_deletion    = true
  enable_snapshot_retention = true
}
