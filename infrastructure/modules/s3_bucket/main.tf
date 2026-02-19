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

# ─── Resources ───────────────────────────────────────────────────

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
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
      sse_algorithm = "aws:kms"
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
