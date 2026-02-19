# ─── Foundation - IAM: Orchestration (Step Functions) ────────────
# Role assumed by AWS Step Functions state machines.
# Scoped to start / monitor Glue jobs prefixed with {domain_abbr}-.

module "sfn_execution_role" {
  source              = "../modules/iam_role"
  role_name           = "${var.domain_abbr}-sfn-exec-${var.env}"
  assume_role_service = "states.amazonaws.com"
  inline_policy_json  = data.aws_iam_policy_document.sfn_permissions.json
  tags                = local.common_tags
}

data "aws_iam_policy_document" "sfn_permissions" {

  # Glue job execution - scoped to domain jobs
  statement {
    sid = "GlueJobExecution"
    actions = [
      "glue:StartJobRun",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:BatchStopJobRun",
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:job/${var.domain_abbr}-*",
    ]
  }

  # CloudWatch Logs - Step Functions execution logs
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
