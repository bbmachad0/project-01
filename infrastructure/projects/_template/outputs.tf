# ─── Project Outputs ─────────────────────────────────────────────
# Export job names, table names, pipeline ARNs, etc. for visibility
# and cross-project references if needed.
#
# Example:
#
#   output "job_names" {
#     description = "List of Glue job names in this project."
#     value       = [module.job_ingest_events.job_name]
#   }
#
#   output "table_names" {
#     description = "List of table names in this project."
#     value       = [module.table_raw_events.table_name, module.table_curated_summary.table_name]
#   }
#
#   output "pipeline_arns" {
#     description = "List of pipeline ARNs in this project."
#     value       = [module.pipeline_ingest.state_machine_arn]
#   }
