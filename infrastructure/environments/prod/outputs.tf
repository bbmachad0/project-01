# ─── Environment Outputs ─────────────────────────────────────────
# Re-exports every baseline output so that per-project stacks can
# read them via terraform_remote_state.  This file is identical
# across dev / int / prod - do NOT customise it.
# ─────────────────────────────────────────────────────────────────

# ── Domain ───────────────────────────────────────────────────────

output "domain_name" {
  value = module.baseline.domain_name
}

output "domain_abbr" {
  value = module.baseline.domain_abbr
}

output "country_code" {
  value = module.baseline.country_code
}

# ── S3 ───────────────────────────────────────────────────────────

output "s3_raw_bucket_arn" {
  value = module.baseline.s3_raw_bucket_arn
}

output "s3_raw_bucket_id" {
  value = module.baseline.s3_raw_bucket_id
}

output "s3_refined_bucket_arn" {
  value = module.baseline.s3_refined_bucket_arn
}

output "s3_refined_bucket_id" {
  value = module.baseline.s3_refined_bucket_id
}

output "s3_curated_bucket_arn" {
  value = module.baseline.s3_curated_bucket_arn
}

output "s3_curated_bucket_id" {
  value = module.baseline.s3_curated_bucket_id
}

output "s3_artifacts_bucket_arn" {
  value = module.baseline.s3_artifacts_bucket_arn
}

output "s3_artifacts_bucket_id" {
  value = module.baseline.s3_artifacts_bucket_id
}

output "s3_logs_bucket_id" {
  value = module.baseline.s3_logs_bucket_id
}

output "s3_logs_bucket_arn" {
  value = module.baseline.s3_logs_bucket_arn
}

# ── IAM ──────────────────────────────────────────────────────────

output "sfn_execution_role_arn" {
  value = module.baseline.sfn_execution_role_arn
}

# ── KMS ──────────────────────────────────────────────────────────

output "kms_key_arn" {
  value = module.baseline.kms_key_arn
}

output "kms_key_id" {
  value = module.baseline.kms_key_id
}

# ── Glue Databases ───────────────────────────────────────────────

output "db_raw_name" {
  value = module.baseline.db_raw_name
}

output "db_refined_name" {
  value = module.baseline.db_refined_name
}

output "db_curated_name" {
  value = module.baseline.db_curated_name
}

# ── Account / Region ────────────────────────────────────────────

output "account_id" {
  value = module.baseline.account_id
}

output "region" {
  value = module.baseline.region
}

# ── Network ──────────────────────────────────────────────────────

output "vpc_id" {
  value = module.baseline.vpc_id
}

output "private_subnet_ids" {
  value = module.baseline.private_subnet_ids
}

output "private_subnet_arns" {
  value = module.baseline.private_subnet_arns
}

output "glue_connection_name" {
  value = module.baseline.glue_connection_name
}

# ── Observability ────────────────────────────────────────────────

output "sns_pipeline_alerts_arn" {
  value = module.baseline.sns_pipeline_alerts_arn
}
