# ─── Project: Customers — Outputs ────────────────────────────────

output "job_names" {
  description = "Glue job names in the Customers project."
  value       = [module.job_customer_delta.job_name]
}

output "table_names" {
  description = "Table names in the Customers project."
  value = [
    module.table_raw_customer_cdc.table_name,
    module.table_customers.table_name,
  ]
}

output "pipeline_arns" {
  description = "Pipeline ARNs in the Customers project."
  value       = [module.pipeline_customers.state_machine_arn]
}
