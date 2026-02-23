# ─── Foundation - KMS: Data Lake Encryption ──────────────────────
# Customer-managed key for S3 bucket encryption.
# Enables custom rotation policy, granular key policies, and
# cross-account access control.

# ─── Key Policy ─────────────────────────────────────────────────
# Explicit policy is required. Without it the default key policy grants
# root full access, but does not allow services (e.g. CloudWatch Logs)
# to use the key even if their IAM policies permit it.

data "aws_iam_policy_document" "kms_key_policy" {

  # Root account full control - mandatory for key management and
  # to allow IAM identity-based policies to delegate key usage.
  statement {
    sid    = "RootAccountFullControl"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # All IAM roles belonging to this domain (Glue, SFN, optimizers, VPC flow
  # logs) may use the key for data encryption. Scoped by role name prefix.
  statement {
    sid    = "DomainRolesKeyUsage"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:ReEncrypt*",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.domain_abbr}-*"]
    }
  }

  # CloudWatch Logs service must be explicitly granted access in the key
  # policy - IAM policies alone are insufficient for service principals.
  # Required for encrypted VPC Flow Log groups and SFN log groups.
  # See: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html
  statement {
    sid    = "CloudWatchLogsEncryption"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}

# ─── Resources ──────────────────────────────────────────────────

resource "aws_kms_key" "data_lake" {
  description             = "KMS key for ${var.domain_abbr} data lake encryption - ${var.env}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
  tags                    = local.common_tags
}

resource "aws_kms_alias" "data_lake" {
  name          = "alias/${var.domain_abbr}-data-lake-${var.env}"
  target_key_id = aws_kms_key.data_lake.id
}
