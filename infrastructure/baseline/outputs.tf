# ─── Baseline - Outputs ──────────────────────────────────────────

# ── Domain ───────────────────────────────────────────────────────

output "domain_name" {
  value = var.domain_name
}

output "domain_abbr" {
  value = var.domain_abbr
}

output "country_code" {
  value = var.country_code
}

# ── S3 ───────────────────────────────────────────────────────────

output "s3_raw_bucket_arn" {
  value = module.s3_raw.bucket_arn
}

output "s3_raw_bucket_id" {
  value = module.s3_raw.bucket_id
}

output "s3_refined_bucket_arn" {
  value = module.s3_refined.bucket_arn
}

output "s3_refined_bucket_id" {
  value = module.s3_refined.bucket_id
}

output "s3_curated_bucket_arn" {
  value = module.s3_curated.bucket_arn
}

output "s3_curated_bucket_id" {
  value = module.s3_curated.bucket_id
}

output "s3_artifacts_bucket_arn" {
  value = module.s3_artifacts.bucket_arn
}

output "s3_artifacts_bucket_id" {
  value = module.s3_artifacts.bucket_id
}

output "s3_logs_bucket_id" {
  value = module.s3_logs.bucket_id
}

output "s3_logs_bucket_arn" {
  value = module.s3_logs.bucket_arn
}

# ── IAM ──────────────────────────────────────────────────────────
# Glue execution and Table Optimizer roles are now per-project
# (see projects/<name>/iam.tf).  Only the StepFunctions role
# remains domain-wide.

output "sfn_execution_role_arn" {
  value = module.sfn_execution_role.role_arn
}

# ── KMS ──────────────────────────────────────────────────────────

output "kms_key_arn" {
  value = aws_kms_key.data_lake.arn
}

output "kms_key_id" {
  value = aws_kms_key.data_lake.id
}

# ── Glue Databases ───────────────────────────────────────────────

output "db_raw_name" {
  value = module.db_raw.database_name
}

output "db_refined_name" {
  value = module.db_refined.database_name
}

output "db_curated_name" {
  value = module.db_curated.database_name
}

# ── Account / Region (convenience for downstream modules) ───────

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = data.aws_region.current.name
}

# ── Network ──────────────────────────────────────────────────────

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_subnet_arns" {
  value = aws_subnet.private[*].arn
}

output "glue_connection_name" {
  description = "Name of the domain-level Glue VPC connection (shared by all jobs)."
  value       = aws_glue_connection.main.name
}

# ── Observability ────────────────────────────────────────────────

output "sns_pipeline_alerts_arn" {
  description = "ARN of the SNS topic for pipeline and Glue job failure alerts."
  value       = aws_sns_topic.pipeline_alerts.arn
}
