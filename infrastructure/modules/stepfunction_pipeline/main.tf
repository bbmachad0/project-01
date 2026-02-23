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

# ─── Dynamic ASL Definition ──────────────────────────────────────

locals {
  # Sanitise job names for use as state names (hyphens → underscores)
  sanitised_names = [for name in var.glue_job_names : replace(name, "-", "_")]

  # Build sequential states from job names.
  # Each state is jsonencode'd individually and decoded back via jsondecode
  # to preserve native types (bool for "End", string for "Next").
  # Using merge() would coerce all values to string, producing "End": "true"
  # instead of "End": true — which fails ASL schema validation.
  states = { for i, name in var.glue_job_names :
    "Run_${local.sanitised_names[i]}" => jsondecode(
      i < length(var.glue_job_names) - 1
      ? jsonencode({
          Type     = "Task"
          Resource = "arn:aws:states:::glue:startJobRun.sync"
          Parameters = { JobName = name }
          Next     = "Run_${local.sanitised_names[i + 1]}"
        })
      : jsonencode({
          Type     = "Task"
          Resource = "arn:aws:states:::glue:startJobRun.sync"
          Parameters = { JobName = name }
          End      = true
        })
    )
  }

  # Build the full ASL definition as a JSON string.
  # Each branch is encoded independently to avoid Terraform's
  # "inconsistent conditional result types" error — the dynamic
  # state keys in local.states differ from the static fallback object.
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
