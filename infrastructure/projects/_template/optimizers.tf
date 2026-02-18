# ─── Table Optimizers ────────────────────────────────────────────
# Wire Glue Table Optimizers for each ICEBERG table in this project.
# Standard (Hive) tables do NOT support optimizers — skip them.
#
# Example:
#
#   module "optimizer_curated_summary" {
#     source = "../../modules/glue_table_optimizer"
#
#     catalog_id    = var.account_id
#     database_name = module.table_curated_summary.database_name
#     table_name    = module.table_curated_summary.table_name
#     role_arn      = var.table_optimizer_role_arn
#
#     enable_compaction         = true
#     enable_orphan_deletion    = true
#     enable_snapshot_retention = true
#   }
