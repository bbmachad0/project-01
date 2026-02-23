# ─── S3 Bucket Module ────────────────────────────────────────────
# Creates an S3 bucket with encryption, versioning, lifecycle, and
# public-access blocking configured for enterprise compliance.

variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

variable "enable_versioning" {
  description = "Enable object versioning."
  type        = bool
  default     = true
}

variable "lifecycle_noncurrent_days" {
  description = "Days before non-current object versions are deleted."
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "enable_logging" {
  description = "Enable S3 server access logging. When true, logging_bucket_id must be set."
  type        = bool
  default     = false
}

variable "logging_bucket_id" {
  description = "S3 bucket ID for server access logging."
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "Prefix for access log objects within the logging bucket."
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "ARN of a KMS CMK for S3 encryption. If empty, uses AWS-managed key."
  type        = string
  default     = ""
}

# ─── Resources ───────────────────────────────────────────────────

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags

  lifecycle {
    # Prevents accidental data loss on bucket renames or module removal.
    # To intentionally destroy a bucket, remove this block temporarily.
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "cleanup-noncurrent"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.lifecycle_noncurrent_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ─── Access Logging ──────────────────────────────────────────────

resource "aws_s3_bucket_logging" "this" {
  count         = var.enable_logging ? 1 : 0
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_bucket_id
  target_prefix = var.logging_prefix != "" ? var.logging_prefix : "${aws_s3_bucket.this.id}/"
}

# ─── Bucket Policy: Deny Insecure Transport ─────────────────────

data "aws_iam_policy_document" "deny_insecure" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
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

resource "aws_s3_bucket_policy" "deny_insecure" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.deny_insecure.json
}

# ─── Outputs ─────────────────────────────────────────────────────

output "bucket_id" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  value = aws_s3_bucket.this.bucket_regional_domain_name
}
