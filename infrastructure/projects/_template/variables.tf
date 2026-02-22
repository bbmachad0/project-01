# ─── Project Stack - Variables ───────────────────────────────────
# These are injected by the projects/ aggregator from foundation outputs.
# You should NOT need to change this file when creating a new project.

variable "domain_abbr" {
  description = "Domain abbreviation for resource naming (e.g. nl)."
  type        = string
}

variable "project_slug" {
  description = "Short unique slug for this project (e.g. sales, cust, legacy)."
  type        = string
}

variable "env" {
  description = "Environment (dev, int, prod)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "artifacts_bucket" {
  description = "S3 bucket ID for scripts and wheels."
  type        = string
}

variable "raw_bucket" {
  description = "S3 bucket ID for the raw data layer."
  type        = string
}

variable "refined_bucket" {
  description = "S3 bucket ID for the refined data layer."
  type        = string
}

variable "curated_bucket" {
  description = "S3 bucket ID for the curated data layer."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "sfn_execution_role_arn" {
  description = "IAM role ARN for Step Functions."
  type        = string
}

variable "db_raw_name" {
  description = "Glue Catalog database - raw layer."
  type        = string
}

variable "db_refined_name" {
  description = "Glue Catalog database - refined layer."
  type        = string
}

variable "db_curated_name" {
  description = "Glue Catalog database - curated layer."
  type        = string
}

variable "glue_connection_name" {
  description = "Name of the domain-level Glue VPC connection (shared by all jobs)."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all resources."
  type        = map(string)
}
