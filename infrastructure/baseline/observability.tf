# ─── Baseline - Observability & Alerting ─────────────────────────
# SNS topic for pipeline/job alerts, plus EventBridge rules that
# capture Step Functions and Glue Job failures and route them to SNS.
#
# Projects and teams subscribe to the topic (email, Slack webhook
# via Lambda, PagerDuty, etc.) outside this module.

# ─── SNS Topic ───────────────────────────────────────────────────

resource "aws_sns_topic" "pipeline_alerts" {
  name              = "${var.domain_abbr}-pipeline-alerts-${var.env}"
  kms_master_key_id = aws_kms_key.data_lake.arn

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-pipeline-alerts-${var.env}"
  })
}

# Allow EventBridge to publish to the topic.
resource "aws_sns_topic_policy" "pipeline_alerts" {
  arn    = aws_sns_topic.pipeline_alerts.arn
  policy = data.aws_iam_policy_document.sns_pipeline_alerts.json
}

data "aws_iam_policy_document" "sns_pipeline_alerts" {
  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.pipeline_alerts.arn]
  }
}

# ─── EventBridge: Step Functions Failures ────────────────────────

resource "aws_cloudwatch_event_rule" "sfn_failure" {
  name        = "${var.domain_abbr}-sfn-failure-${var.env}"
  description = "Capture Step Functions execution failures, timeouts, and aborts."

  event_pattern = jsonencode({
    source      = ["aws.states"]
    detail-type = ["Step Functions Execution Status Change"]
    detail      = { status = ["FAILED", "TIMED_OUT", "ABORTED"] }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "sfn_failure_sns" {
  rule      = aws_cloudwatch_event_rule.sfn_failure.name
  target_id = "sfn-failure-to-sns"
  arn       = aws_sns_topic.pipeline_alerts.arn
}

# ─── EventBridge: Glue Job Failures ──────────────────────────────

resource "aws_cloudwatch_event_rule" "glue_job_failure" {
  name        = "${var.domain_abbr}-glue-job-failure-${var.env}"
  description = "Capture Glue job failures, timeouts, and errors."

  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Job State Change"]
    detail      = { state = ["FAILED", "TIMEOUT", "ERROR"] }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "glue_job_failure_sns" {
  rule      = aws_cloudwatch_event_rule.glue_job_failure.name
  target_id = "glue-failure-to-sns"
  arn       = aws_sns_topic.pipeline_alerts.arn
}
