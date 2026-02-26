# ─── Baseline - S3 Buckets ─────────────────────────────────────
# Data-lake layer buckets + artifacts bucket for the domain.
#
# Naming convention:  {domain_abbr}-{purpose}-{account_id}-{country_code}-{env}
# Example:            f01-raw-390403879405-de-dev

# ─── Access Logs Bucket ─────────────────────────────────────────
# Dedicated bucket for S3 server access logs. NOT logged itself
# (would cause an infinite loop).

module "s3_logs" {
  source            = "../modules/s3_bucket"
  bucket_name       = "${var.domain_abbr}-logs-${data.aws_caller_identity.current.account_id}-${var.country_code}-${var.env}"
  enable_versioning = false
  kms_key_arn       = aws_kms_key.data_lake.arn
  # Bucket policy is managed externally (below) to combine DenyInsecureTransport
  # with the S3 logging service delivery statement in a single policy resource.
  create_bucket_policy = false
  tags                 = local.common_tags
}

# Allow the S3 logging service to write to the logs bucket
resource "aws_s3_bucket_policy" "logs_delivery" {
  bucket = module.s3_logs.bucket_id
  policy = data.aws_iam_policy_document.logs_delivery.json
}

data "aws_iam_policy_document" "logs_delivery" {

  statement {
    sid    = "S3LogDeliveryWrite"
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${module.s3_logs.bucket_arn}/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [
      module.s3_logs.bucket_arn,
      "${module.s3_logs.bucket_arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# ─── Data-Lake Buckets ───────────────────────────────────────────

module "s3_raw" {
  source            = "../modules/s3_bucket"
  bucket_name       = "${var.domain_abbr}-raw-${data.aws_caller_identity.current.account_id}-${var.country_code}-${var.env}"
  enable_logging    = true
  logging_bucket_id = module.s3_logs.bucket_id
  logging_prefix    = "raw/"
  kms_key_arn       = aws_kms_key.data_lake.arn
  tags              = local.common_tags
}

module "s3_refined" {
  source            = "../modules/s3_bucket"
  bucket_name       = "${var.domain_abbr}-refined-${data.aws_caller_identity.current.account_id}-${var.country_code}-${var.env}"
  enable_logging    = true
  logging_bucket_id = module.s3_logs.bucket_id
  logging_prefix    = "refined/"
  kms_key_arn       = aws_kms_key.data_lake.arn
  tags              = local.common_tags
}

module "s3_curated" {
  source            = "../modules/s3_bucket"
  bucket_name       = "${var.domain_abbr}-curated-${data.aws_caller_identity.current.account_id}-${var.country_code}-${var.env}"
  enable_logging    = true
  logging_bucket_id = module.s3_logs.bucket_id
  logging_prefix    = "curated/"
  kms_key_arn       = aws_kms_key.data_lake.arn
  tags              = local.common_tags
}

module "s3_artifacts" {
  source            = "../modules/s3_bucket"
  bucket_name       = "${var.domain_abbr}-artifacts-${data.aws_caller_identity.current.account_id}-${var.country_code}-${var.env}"
  enable_logging    = true
  logging_bucket_id = module.s3_logs.bucket_id
  logging_prefix    = "artifacts/"
  kms_key_arn       = aws_kms_key.data_lake.arn
  tags              = local.common_tags
}
