# ─── Jobs Layer — Variables ──────────────────────────────────────

variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "artifacts_bucket" {
  description = "S3 bucket ID for job scripts and wheels."
  type        = string
}

variable "glue_execution_role_arn" {
  description = "IAM role ARN for Glue job execution."
  type        = string
}

variable "sfn_execution_role_arn" {
  description = "IAM role ARN for Step Functions execution."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
}
