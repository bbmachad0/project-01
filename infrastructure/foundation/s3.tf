# ─── Foundation - S3 Buckets ─────────────────────────────────────
# Data-lake layer buckets + artifacts bucket for the domain.
#
# Naming convention:  {domain_abbr}-{layer}-{env}
# Example:            nl-raw-dev

module "s3_raw" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.domain_abbr}-raw-${var.env}"
  tags        = local.common_tags
}

module "s3_curated" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.domain_abbr}-curated-${var.env}"
  tags        = local.common_tags
}

module "s3_warehouse" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.domain_abbr}-warehouse-${var.env}"
  tags        = local.common_tags
}

module "s3_artifacts" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.domain_abbr}-artifacts-${var.env}"
  tags        = local.common_tags
}
