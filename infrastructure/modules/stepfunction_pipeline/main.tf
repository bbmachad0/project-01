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
  description = "Ordered list of Glue job names. Unused by the generic ASL definition; kept for reference and future use."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

# ─── Resource ────────────────────────────────────────────────────

resource "aws_sfn_state_machine" "this" {
  name     = var.pipeline_name
  role_arn = var.role_arn

  definition = file("${path.module}/asl.json")

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
