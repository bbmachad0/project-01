# ─── S3 Artifacts Bucket ─────────────────────────────────────────
# Stores Glue job scripts, .whl libraries, and temporary files.

module "s3_artifacts" {
  source      = "../modules/s3_bucket"
  bucket_name = "${var.project}-artifacts-${var.env}"
  tags        = local.common_tags
}
