# ─── Foundation - KMS: Data Lake Encryption ──────────────────────
# Customer-managed key for S3 bucket encryption.
# Enables custom rotation policy, granular key policies, and
# cross-account access control.

resource "aws_kms_key" "data_lake" {
  description             = "KMS key for ${var.domain_abbr} data lake encryption - ${var.env}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "data_lake" {
  name          = "alias/${var.domain_abbr}-data-lake-${var.env}"
  target_key_id = aws_kms_key.data_lake.id
}
