# ─── IAM Table Optimizer Role ────────────────────────────────────
# Dedicated IAM role assumed by the Glue Table Optimizer service.
# Scoped to the project's S3 buckets and Glue Catalog databases.
#
# Permissions:
#   - S3 read / write / delete (compaction rewrites, orphan cleanup)
#   - Glue Catalog read / update (table metadata refresh)
#   - CloudWatch Logs (optimizer execution logs)

# ─── Variables ───────────────────────────────────────────────────

variable "project" {
  description = "Project identifier — used as the IAM security boundary."
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
  description = "S3 bucket ARNs containing Iceberg table data."
  type        = list(string)
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
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

  # ── S3: read / write / delete for compaction & orphan cleanup ──

  statement {
    sid = "S3ObjectAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [for arn in var.s3_bucket_arns : "${arn}/*"]
  }

  statement {
    sid = "S3BucketAccess"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = var.s3_bucket_arns
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
      "arn:aws:glue:${var.region}:${var.account_id}:database/${var.project}_*",
      "arn:aws:glue:${var.region}:${var.account_id}:table/${var.project}_*/*",
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
}

# ─── Resources ───────────────────────────────────────────────────

resource "aws_iam_role" "table_optimizer" {
  name               = "${var.project}-table-optimizer-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "table_optimizer" {
  name   = "${var.project}-table-optimizer-policy"
  role   = aws_iam_role.table_optimizer.id
  policy = data.aws_iam_policy_document.table_optimizer.json
}

# ─── Outputs ─────────────────────────────────────────────────────

output "role_arn" {
  description = "ARN of the table optimizer IAM role."
  value       = aws_iam_role.table_optimizer.arn
}

output "role_name" {
  description = "Name of the table optimizer IAM role."
  value       = aws_iam_role.table_optimizer.name
}

output "role_id" {
  description = "ID of the table optimizer IAM role."
  value       = aws_iam_role.table_optimizer.id
}
