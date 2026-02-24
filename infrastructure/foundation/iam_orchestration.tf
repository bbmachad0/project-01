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

  # CloudWatch Logs - Step Functions execution logs (log group operations)
  # Scoped to SFN log groups created by this domain only.
  statement {
    sid = "CloudWatchLogsGroups"
    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/states/${var.domain_abbr}-*",
    ]
  }

  # CloudWatch Logs - Step Functions log delivery management
  # Log Delivery API calls do NOT support resource-level ARN restrictions in IAM.
  # AWS requires resources = ["*"] for these actions - see:
  # https://docs.aws.amazon.com/step-functions/latest/dg/cw-logs.html
  # PutResourcePolicy and DeleteLogDelivery are one-time setup/teardown operations
  # performed by Terraform, not runtime requirements. They are intentionally omitted
  # from this role to minimise the blast radius of a compromised execution.
  statement {
    sid = "CloudWatchLogsDelivery"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:ListLogDeliveries",
      "logs:DescribeResourcePolicies",
    ]
    # tfsec:ignore:AWS097 - Log Delivery actions do not support resource-level ARN
    # restrictions. This wildcard is intentional and required by AWS.
    resources = ["*"]
  }
}
