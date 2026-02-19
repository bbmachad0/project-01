# ─── Foundation - Variables & Locals ─────────────────────────────

# ─── Data Sources ────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── Variables ───────────────────────────────────────────────────

variable "domain_name" {
  description = "Full domain name (e.g. finance01). Used in tags and descriptions."
  type        = string
}

variable "domain_abbr" {
  description = "Short domain abbreviation (e.g. nl). Used as prefix for all resource names."
  type        = string
}

variable "env" {
  description = "Deployment environment: dev, int, or prod."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

locals {
  common_tags = {
    domain      = var.domain_name
    domain_abbr = var.domain_abbr
    env         = var.env
    managed_by  = "terraform"
  }

  # Normalised abbreviation for Glue database naming (hyphens → underscores)
  db_prefix = replace(var.domain_abbr, "-", "_")
}
