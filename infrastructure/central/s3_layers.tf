# ─── S3 Data Layer Buckets ───────────────────────────────────────
# Raw, curated, and warehouse buckets forming the data lake layers.

module "s3_raw" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.project}-raw-${var.env}"
  tags        = local.common_tags
}

module "s3_curated" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.project}-curated-${var.env}"
  tags        = local.common_tags
}

module "s3_warehouse" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.project}-warehouse-${var.env}"
  tags        = local.common_tags
}
