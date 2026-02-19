# ─── Per-Project IAM Roles ───────────────────────────────────────
# Each project gets its own Glue execution and Table Optimizer roles.
# S3 data access is scoped to the project_slug prefix in each bucket.
# Glue Catalog access is domain-scoped (shared databases).
#
# This file is identical across all projects - do NOT customise it.
# ─────────────────────────────────────────────────────────────────

locals {
  s3_data_bucket_arns = [
    "arn:aws:s3:::${var.raw_bucket}",
    "arn:aws:s3:::${var.curated_bucket}",
    "arn:aws:s3:::${var.warehouse_bucket}",
  ]
}

# ── Glue Job Execution Role ──────────────────────────────────────

module "iam_glue_job" {
  source = "../../modules/iam_glue_job"

  domain_abbr  = var.domain_abbr
  project_slug = var.project_slug
  env          = var.env
  account_id   = var.account_id
  region       = var.region

  s3_bucket_arns          = local.s3_data_bucket_arns
  s3_artifacts_bucket_arn = "arn:aws:s3:::${var.artifacts_bucket}"

  tags = var.common_tags
}

# ── Table Optimizer Role ─────────────────────────────────────────

module "iam_table_optimizer" {
  source = "../../modules/iam_table_optimizer"

  domain_abbr  = var.domain_abbr
  project_slug = var.project_slug
  env          = var.env
  account_id   = var.account_id
  region       = var.region

  s3_bucket_arns = local.s3_data_bucket_arns

  tags = var.common_tags
}
