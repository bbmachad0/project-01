# ─── Foundation - S3 Buckets ─────────────────────────────────────
# Data-lake layer buckets + artifacts bucket for the domain.
#
# Naming convention:  {domain_abbr}-{purpose}-{account_id}-{env}
# Example:            f01-raw-390403879405-dev

module "s3_raw" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.domain_abbr}-raw-${data.aws_caller_identity.current.account_id}-${var.env}"
  tags        = local.common_tags
}

module "s3_curated" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.domain_abbr}-curated-${data.aws_caller_identity.current.account_id}-${var.env}"
  tags        = local.common_tags
}

module "s3_warehouse" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.domain_abbr}-warehouse-${data.aws_caller_identity.current.account_id}-${var.env}"
  tags        = local.common_tags
}

module "s3_artifacts" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.domain_abbr}-artifacts-${data.aws_caller_identity.current.account_id}-${var.env}"
  tags        = local.common_tags
}
