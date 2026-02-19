output "job_names" {
  description = "Glue job names."
  value       = [module.job_teste.job_name]
}

output "table_names" {
  description = "Table names."
  value       = [module.table_curated_teste.table_name]
}