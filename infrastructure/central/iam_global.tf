# ─── Global IAM Roles ────────────────────────────────────────────
# Shared IAM roles used across all Glue jobs in this domain.

# Glue execution role — grants access to data-lake buckets, Glue
# catalog, CloudWatch, and temporary S3 locations.
module "glue_execution_role" {
  source              = "../modules/iam_role"
  role_name           = "${var.project}-glue-exec-${var.env}"
  assume_role_service = "glue.amazonaws.com"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole",
  ]
  inline_policy_json = data.aws_iam_policy_document.glue_data_access.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "glue_data_access" {
  # S3 data-lake read / write
  statement {
    sid = "S3DataLakeAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      module.s3_raw.bucket_arn,
      "${module.s3_raw.bucket_arn}/*",
      module.s3_curated.bucket_arn,
      "${module.s3_curated.bucket_arn}/*",
      module.s3_warehouse.bucket_arn,
      "${module.s3_warehouse.bucket_arn}/*",
      module.s3_artifacts.bucket_arn,
      "${module.s3_artifacts.bucket_arn}/*",
    ]
  }

  # Glue Data Catalog
  statement {
    sid = "GlueCatalogAccess"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchCreatePartition",
      "glue:BatchDeletePartition",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

# Step Functions execution role
module "sfn_execution_role" {
  source              = "../modules/iam_role"
  role_name           = "${var.project}-sfn-exec-${var.env}"
  assume_role_service = "states.amazonaws.com"
  inline_policy_json  = data.aws_iam_policy_document.sfn_permissions.json
  tags                = local.common_tags
}

data "aws_iam_policy_document" "sfn_permissions" {
  statement {
    sid = "GlueJobExecution"
    actions = [
      "glue:StartJobRun",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:BatchStopJobRun",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
}
