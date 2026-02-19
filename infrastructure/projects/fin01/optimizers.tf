module "optimizer_curated_teste" {
  source = "../../modules/glue_table_optimizer"

  catalog_id    = var.account_id
  database_name = module.table_curated_teste.database_name
  table_name    = module.table_curated_teste.table_name
  role_arn      = var.table_optimizer_role_arn

  enable_compaction         = true
  enable_orphan_deletion    = true
  enable_snapshot_retention = true
}