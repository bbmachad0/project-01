# ─── Baseline - Variables & Locals ───────────────────────────────

# ─── Data Sources ────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── Variables ───────────────────────────────────────────────────

variable "domain_name" {
  description = "Full domain name (e.g. finance01). Used in tags and descriptions."
  type        = string
}

variable "domain_abbr" {
  description = "Short domain abbreviation (e.g. f01). Used as prefix for all resource names."
  type        = string
}

variable "country_code" {
  description = "ISO 3166-1 alpha-2 country code (e.g. de, br). Used in S3 bucket and Glue database naming for multi-region Athena queries."
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
    domain       = var.domain_name
    domain_abbr  = var.domain_abbr
    country_code = var.country_code
    env          = var.env
    managed_by   = "terraform"
  }

  # Normalised abbreviation for Glue database naming (hyphens → underscores)
  # Pattern: {abbr}_{country_code}_{layer}  e.g. f01_de_raw
  db_prefix = "${replace(var.domain_abbr, "-", "_")}_${var.country_code}"
}
