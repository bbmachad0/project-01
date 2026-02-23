# ─── IAM Table Optimizer Role ────────────────────────────────────
# Dedicated IAM role assumed by the Glue Table Optimizer service.
# Scoped to the project's S3 prefix and domain Glue Catalog databases.
#
# Permissions:
#   - S3 read / write / delete scoped to {project_slug}/* prefix
#   - Glue Catalog read / update (table metadata refresh)
#   - CloudWatch Logs (optimizer execution logs)

# ─── Variables ───────────────────────────────────────────────────

variable "domain_abbr" {
  description = "Domain abbreviation - used for Glue Catalog database scoping ({domain_abbr}_*)."
  type        = string
}

variable "project_slug" {
  description = "Project slug - used for role naming and S3 prefix scoping."
  type        = string
}

variable "env" {
  description = "Environment (dev, int, prod)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID for ARN construction."
  type        = string
}

variable "region" {
  description = "AWS region for ARN construction."
  type        = string
}

variable "s3_bucket_arns" {
  description = "S3 bucket ARNs containing Iceberg table data. Access scoped to project_slug prefix."
  type        = list(string)
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the KMS CMK used for S3 encryption. If empty, KMS permissions are not added."
  type        = string
  default     = ""
}

# ─── Data Sources ────────────────────────────────────────────────

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "table_optimizer" {

  # ── S3: read / write / delete scoped to project prefix ────────

  statement {
    sid = "S3ObjectAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [for arn in var.s3_bucket_arns : "${arn}/${var.project_slug}/*"]
  }

  statement {
    sid = "S3BucketList"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = var.s3_bucket_arns

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.project_slug}/*", "${var.project_slug}"]
    }
  }

  # ── Glue Catalog: read + update for table metadata refresh ─────

  statement {
    sid = "GlueCatalogAccess"
    actions = [
      "glue:GetTable",
      "glue:GetTables",
      "glue:UpdateTable",
      "glue:GetDatabase",
    ]
    resources = [
      "arn:aws:glue:${var.region}:${var.account_id}:catalog",
      "arn:aws:glue:${var.region}:${var.account_id}:database/${var.domain_abbr}_*",
      "arn:aws:glue:${var.region}:${var.account_id}:table/${var.domain_abbr}_*/*",
    ]
  }

  # ── CloudWatch Logs ────────────────────────────────────────────

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws-glue/*",
    ]
  }

  # ── KMS: Data lake encryption key ───────────────────────────

  dynamic "statement" {
    for_each = var.kms_key_arn != "" ? [1] : []
    content {
      sid = "KMSDataLakeAccess"
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
      ]
      resources = [var.kms_key_arn]
    }
  }
}

# ─── Resources ───────────────────────────────────────────────────

resource "aws_iam_role" "table_optimizer" {
  name               = "${var.domain_abbr}-optimizer-${var.project_slug}-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "table_optimizer" {
  name   = "${var.domain_abbr}-optimizer-${var.project_slug}-policy"
  role   = aws_iam_role.table_optimizer.id
  policy = data.aws_iam_policy_document.table_optimizer.json
}

# IAM is eventually consistent: a newly created role may not be visible to
# the Glue API immediately, causing CreateTableOptimizer to return
# AccessDeniedException.  This sleep gives IAM time to propagate globally
# before any optimizer resource tries to reference this role.
resource "time_sleep" "iam_propagation" {
  depends_on      = [aws_iam_role.table_optimizer, aws_iam_role_policy.table_optimizer]
  create_duration = "20s"
}

# ─── Outputs ─────────────────────────────────────────────────────

output "role_arn" {
  description = "ARN of the table optimizer IAM role."
  # depends_on ensures consumers (glue_iceberg_table optimizers) wait for
  # the IAM propagation sleep before calling CreateTableOptimizer.
  depends_on = [time_sleep.iam_propagation]
  value      = aws_iam_role.table_optimizer.arn
}

output "role_name" {
  description = "Name of the table optimizer IAM role."
  value       = aws_iam_role.table_optimizer.name
}

output "role_id" {
  description = "ID of the table optimizer IAM role."
  value       = aws_iam_role.table_optimizer.id
}
