# ─── Per-Project IAM Roles ───────────────────────────────────────
# Each project gets its own Glue execution and Table Optimizer roles.
# S3 data access is scoped to the project_name prefix in each bucket.
# Glue Catalog access is domain-scoped (shared databases).
#
# This file is identical across all projects - do NOT customise it.
# ─────────────────────────────────────────────────────────────────

locals {
  s3_data_bucket_arns = [
    "arn:aws:s3:::${local.baseline.s3_raw_bucket_id}",
    "arn:aws:s3:::${local.baseline.s3_refined_bucket_id}",
    "arn:aws:s3:::${local.baseline.s3_curated_bucket_id}",
  ]
}

# ── Glue Job Execution Role ──────────────────────────────────────

module "iam_glue_job" {
  source = "../../modules/iam_glue_job"

  domain_abbr  = local.baseline.domain_abbr
  project_name = local.config.name
  env          = var.environment
  account_id   = data.aws_caller_identity.current.account_id
  region       = local.domain.aws_region

  s3_bucket_arns          = local.s3_data_bucket_arns
  s3_artifacts_bucket_arn = "arn:aws:s3:::${local.baseline.s3_artifacts_bucket_id}"
  kms_key_arn             = local.baseline.kms_key_arn
  subnet_arns             = local.baseline.private_subnet_arns

  tags = local.tags
}

# ── Table Optimizer Role ─────────────────────────────────────────

module "iam_table_optimizer" {
  source = "../../modules/iam_table_optimizer"

  domain_abbr  = local.baseline.domain_abbr
  project_name = local.config.name
  env          = var.environment
  account_id   = data.aws_caller_identity.current.account_id
  region       = local.domain.aws_region

  s3_bucket_arns = local.s3_data_bucket_arns
  kms_key_arn    = local.baseline.kms_key_arn

  tags = local.tags
}
