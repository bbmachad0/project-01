# ─── IAM Glue Job Execution Role ─────────────────────────────────
# Purpose-built IAM role for AWS Glue job execution in a Data Mesh
# domain.  Scoped to project-level boundaries:
#
#   - S3 access limited to provided bucket ARNs
#   - Glue Catalog limited to {project}_* databases + "default"
#   - SSM Parameter Store read under /{project}/*
#   - CloudWatch Logs for /aws-glue/* log groups
#   - EC2 networking for VPC-connected jobs

# ─── Variables ───────────────────────────────────────────────────

variable "project" {
  description = "Project identifier - used as the IAM security boundary."
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
  description = "List of S3 bucket ARNs the Glue job may access."
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

data "aws_iam_policy_document" "glue_job" {

  # ── S3: object-level access on project buckets ─────────────────

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

  # ── Glue Data Catalog: project databases + default (Iceberg) ───

  statement {
    sid = "GlueCatalogRead"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchGetPartition",
      "glue:SearchTables",
    ]
    resources = [
      "arn:aws:glue:${var.region}:${var.account_id}:catalog",
      "arn:aws:glue:${var.region}:${var.account_id}:database/${var.project}_*",
      "arn:aws:glue:${var.region}:${var.account_id}:table/${var.project}_*/*",
      "arn:aws:glue:${var.region}:${var.account_id}:database/default",
      "arn:aws:glue:${var.region}:${var.account_id}:table/default/*",
    ]
  }

  statement {
    sid = "GlueCatalogWrite"
    actions = [
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:BatchCreatePartition",
      "glue:BatchDeletePartition",
      "glue:UpdatePartition",
      "glue:CreatePartition",
      "glue:DeletePartition",
    ]
    resources = [
      "arn:aws:glue:${var.region}:${var.account_id}:catalog",
      "arn:aws:glue:${var.region}:${var.account_id}:database/${var.project}_*",
      "arn:aws:glue:${var.region}:${var.account_id}:table/${var.project}_*/*",
    ]
  }

  # ── SSM Parameter Store: project-scoped read ───────────────────

  statement {
    sid = "SSMParameterRead"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.project}/*",
    ]
  }

  # ── CloudWatch Logs ────────────────────────────────────────────

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:AssociateKmsKey",
    ]
    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws-glue/*",
    ]
  }

  # ── CloudWatch Metrics (Spark UI + custom metrics) ─────────────

  statement {
    sid       = "CloudWatchMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["Glue"]
    }
  }

  # ── EC2: VPC networking for Glue connections ───────────────────

  statement {
    sid = "EC2NetworkAccess"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeRouteTables",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EC2TagNetworkInterface"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:network-interface/*",
    ]
  }
}

# ─── Resources ───────────────────────────────────────────────────

resource "aws_iam_role" "glue_job" {
  name               = "${var.project}-glue-job-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "glue_job" {
  name   = "${var.project}-glue-job-policy"
  role   = aws_iam_role.glue_job.id
  policy = data.aws_iam_policy_document.glue_job.json
}

# ─── Outputs ─────────────────────────────────────────────────────

output "role_arn" {
  description = "ARN of the Glue job execution role."
  value       = aws_iam_role.glue_job.arn
}

output "role_name" {
  description = "Name of the Glue job execution role."
  value       = aws_iam_role.glue_job.name
}

output "role_id" {
  description = "ID of the Glue job execution role."
  value       = aws_iam_role.glue_job.id
}
