# ─── Step Functions Pipeline Module ──────────────────────────────
# Creates an AWS Step Functions state machine that orchestrates
# one or more Glue jobs in sequence.  The ASL definition is
# generated dynamically from the list of Glue job names.

variable "pipeline_name" {
  description = "Name of the Step Functions state machine."
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN assumed by the state machine."
  type        = string
}

variable "glue_job_names" {
  description = "Ordered list of Glue job names to execute sequentially."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt the CloudWatch log group. If empty, AWS-managed encryption is used."
  type        = string
  default     = ""
}

variable "max_retry_attempts" {
  description = "Maximum number of automatic retries per Glue job step on transient failure."
  type        = number
  default     = 2
}

variable "retry_interval_seconds" {
  description = "Initial delay (seconds) before the first retry.  Subsequent retries use exponential backoff (2x)."
  type        = number
  default     = 60
}

variable "retry_backoff_rate" {
  description = "Multiplier applied to the retry interval after each attempt."
  type        = number
  default     = 2.0
}

# ─── Dynamic ASL Definition ──────────────────────────────────────

locals {
  # Sanitise job names for use as state names (hyphens → underscores)
  sanitised_names = [for name in var.glue_job_names : replace(name, "-", "_")]

  # Build sequential states from job names.
  # Each state includes Retry with exponential backoff and a Catch
  # block that routes failures to a terminal PipelineFailed state.
  states = merge(
    { for i, name in var.glue_job_names :
      "Run_${local.sanitised_names[i]}" => jsondecode(jsonencode({
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = name }
        Retry = [{
          ErrorEquals     = ["States.ALL"]
          IntervalSeconds = var.retry_interval_seconds
          MaxAttempts     = var.max_retry_attempts
          BackoffRate     = var.retry_backoff_rate
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "PipelineFailed"
        }]
        Next = i < length(var.glue_job_names) - 1 ? "Run_${local.sanitised_names[i + 1]}" : "PipelineSucceeded"
      }))
    },
    {
      PipelineSucceeded = { Type = "Succeed" }
      PipelineFailed    = { Type = "Fail", Error = "PipelineFailed", Cause = "One or more Glue jobs failed after retries." }
    }
  )

  # Build the full ASL definition as a JSON string.
  definition_json = length(var.glue_job_names) > 0 ? jsonencode({
    Comment = "Auto-generated pipeline for ${var.pipeline_name}"
    StartAt = "Run_${local.sanitised_names[0]}"
    States  = local.states
  }) : jsonencode({
    Comment = "Auto-generated pipeline for ${var.pipeline_name}"
    StartAt = "PipelineEnd"
    States = {
      PipelineEnd = {
        Type = "Succeed"
      }
    }
  })
}

# ─── Resource ────────────────────────────────────────────────────

resource "aws_sfn_state_machine" "this" {
  name     = var.pipeline_name
  role_arn = var.role_arn

  definition = local.definition_json

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.this.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/stepfunctions/${var.pipeline_name}"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null
  tags              = var.tags
}

# ─── Outputs ─────────────────────────────────────────────────────

output "state_machine_arn" {
  value = aws_sfn_state_machine.this.arn
}

output "state_machine_name" {
  value = aws_sfn_state_machine.this.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
