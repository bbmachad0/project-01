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

# ─── Dynamic ASL Definition ──────────────────────────────────────

locals {
  # Sanitise job names for use as state names (hyphens → underscores)
  sanitised_names = [for name in var.glue_job_names : replace(name, "-", "_")]

  # Build sequential states from job names
  states = { for i, name in var.glue_job_names :
    "Run_${local.sanitised_names[i]}" => merge(
      {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = name
        }
      },
      i < length(var.glue_job_names) - 1
      ? { Next = "Run_${local.sanitised_names[i + 1]}" }
      : { End = true }
    )
  }

  full_definition = {
    Comment = "Auto-generated pipeline for ${var.pipeline_name}"
    StartAt = length(var.glue_job_names) > 0 ? "Run_${local.sanitised_names[0]}" : "PipelineEnd"
    States = length(var.glue_job_names) > 0 ? local.states : {
      PipelineEnd = {
        Type = "Succeed"
      }
    }
  }
}

# ─── Resource ────────────────────────────────────────────────────

resource "aws_sfn_state_machine" "this" {
  name     = var.pipeline_name
  role_arn = var.role_arn

  definition = jsonencode(local.full_definition)

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
