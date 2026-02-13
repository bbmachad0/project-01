# ─── Step Functions Pipeline Module ──────────────────────────────
# Creates an AWS Step Functions state machine that orchestrates
# one or more Glue jobs in sequence (or parallel).

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
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

# ─── Locals ──────────────────────────────────────────────────────

locals {
  # Build a chain of Glue job states dynamically.
  job_count = length(var.glue_job_names)

  states = {
    for idx, name in var.glue_job_names : "Run_${replace(name, "-", "_")}" => {
      Type     = "Task"
      Resource = "arn:aws:states:::glue:startJobRun.sync"
      Parameters = {
        JobName = name
      }
      Next    = idx < local.job_count - 1 ? "Run_${replace(var.glue_job_names[idx + 1], "-", "_")}" : null
      End     = idx == local.job_count - 1 ? true : null
      Retry = [
        {
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 60
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }
      ]
      Catch = [
        {
          ErrorEquals = ["States.ALL"]
          Next        = "PipelineFailed"
        }
      ]
    }
  }

  definition = jsonencode({
    Comment = "Pipeline: ${var.pipeline_name}"
    StartAt = "Run_${replace(var.glue_job_names[0], "-", "_")}"
    States = merge(local.states, {
      PipelineFailed = {
        Type  = "Fail"
        Error = "PipelineExecutionFailed"
        Cause = "One or more Glue jobs failed. Check CloudWatch logs."
      }
    })
  })
}

# ─── Resource ────────────────────────────────────────────────────

resource "aws_sfn_state_machine" "this" {
  name     = var.pipeline_name
  role_arn = var.role_arn

  definition = local.definition

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
