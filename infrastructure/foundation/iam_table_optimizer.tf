# ─── Foundation - IAM: Table Optimizer ───────────────────────────
# Dedicated role for the Glue Table Optimizer service.
# Only needs access to curated / warehouse buckets (where Iceberg
# tables live) - not raw or artifacts.

module "iam_table_optimizer" {
  source = "../modules/iam_table_optimizer"

  project    = var.domain_abbr
  env        = var.env
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  s3_bucket_arns = [
    module.s3_curated.bucket_arn,
    module.s3_warehouse.bucket_arn,
  ]

  tags = local.common_tags
}
