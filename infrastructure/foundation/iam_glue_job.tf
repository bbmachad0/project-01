# ─── Foundation - IAM: Glue Job Execution ────────────────────────
# Domain-scoped execution role shared by all Glue jobs.
# See modules/iam_glue_job for the full policy breakdown.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "iam_glue_job" {
  source = "../modules/iam_glue_job"

  project    = var.domain_abbr
  env        = var.env
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  s3_bucket_arns = [
    module.s3_raw.bucket_arn,
    module.s3_curated.bucket_arn,
    module.s3_warehouse.bucket_arn,
    module.s3_artifacts.bucket_arn,
  ]

  tags = local.common_tags
}
