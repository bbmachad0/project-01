# ─── Project: Sales — Outputs ────────────────────────────────────

output "job_names" {
  description = "Glue job names in the Sales project."
  value       = [module.job_daily_sales.job_name]
}

output "table_names" {
  description = "Table names in the Sales project."
  value = [
    module.table_raw_sales_events.table_name,
    module.table_daily_sales.table_name,
  ]
}

output "pipeline_arns" {
  description = "Pipeline ARNs in the Sales project."
  value       = [module.pipeline_sales.state_machine_arn]
}
