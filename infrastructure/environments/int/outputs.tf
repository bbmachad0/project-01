# ─── Environment Outputs ─────────────────────────────────────────
# Re-exports every foundation output so that per-project stacks can
# read them via terraform_remote_state.  This file is identical
# across dev / int / prod - do NOT customise it.
# ─────────────────────────────────────────────────────────────────

# ── Domain ───────────────────────────────────────────────────────

output "domain_name" {
  value = module.foundation.domain_name
}

output "domain_abbr" {
  value = module.foundation.domain_abbr
}

# ── S3 ───────────────────────────────────────────────────────────

output "s3_raw_bucket_arn" {
  value = module.foundation.s3_raw_bucket_arn
}

output "s3_raw_bucket_id" {
  value = module.foundation.s3_raw_bucket_id
}

output "s3_refined_bucket_arn" {
  value = module.foundation.s3_refined_bucket_arn
}

output "s3_refined_bucket_id" {
  value = module.foundation.s3_refined_bucket_id
}

output "s3_curated_bucket_arn" {
  value = module.foundation.s3_curated_bucket_arn
}

output "s3_curated_bucket_id" {
  value = module.foundation.s3_curated_bucket_id
}

output "s3_artifacts_bucket_arn" {
  value = module.foundation.s3_artifacts_bucket_arn
}

output "s3_artifacts_bucket_id" {
  value = module.foundation.s3_artifacts_bucket_id
}

output "s3_logs_bucket_id" {
  value = module.foundation.s3_logs_bucket_id
}

output "s3_logs_bucket_arn" {
  value = module.foundation.s3_logs_bucket_arn
}

# ── IAM ──────────────────────────────────────────────────────────

output "sfn_execution_role_arn" {
  value = module.foundation.sfn_execution_role_arn
}

# ── KMS ──────────────────────────────────────────────────────────

output "kms_key_arn" {
  value = module.foundation.kms_key_arn
}

output "kms_key_id" {
  value = module.foundation.kms_key_id
}

# ── Glue Databases ───────────────────────────────────────────────

output "db_raw_name" {
  value = module.foundation.db_raw_name
}

output "db_refined_name" {
  value = module.foundation.db_refined_name
}

output "db_curated_name" {
  value = module.foundation.db_curated_name
}

# ── Account / Region ────────────────────────────────────────────

output "account_id" {
  value = module.foundation.account_id
}

output "region" {
  value = module.foundation.region
}

# ── Network ──────────────────────────────────────────────────────

output "vpc_id" {
  value = module.foundation.vpc_id
}

output "private_subnet_ids" {
  value = module.foundation.private_subnet_ids
}

output "private_subnet_arns" {
  value = module.foundation.private_subnet_arns
}

output "glue_connection_name" {
  value = module.foundation.glue_connection_name
}
