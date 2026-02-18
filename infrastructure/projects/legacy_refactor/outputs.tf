# ─── Project: Legacy Refactor — Outputs ──────────────────────────

output "job_names" {
  description = "Glue job names in the Legacy Refactor project."
  value       = [module.job_legacy_step01.job_name]
}

output "table_names" {
  description = "Table names in the Legacy Refactor project."
  value = [
    module.table_raw_legacy_dump.table_name,
    module.table_legacy_events.table_name,
  ]
}

output "pipeline_arns" {
  description = "Pipeline ARNs in the Legacy Refactor project."
  value       = [module.pipeline_legacy.state_machine_arn]
}
