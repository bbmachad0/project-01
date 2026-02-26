# ─── Project Stack - Providers ───────────────────────────────────
# This file is identical across all projects - do NOT customise it.
# The project name and all shared values come from locals.tf / data.tf.
# ─────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Backend is configured at runtime via -backend-config flags.
  # See CI/CD workflows or: make tf-init ENV=dev PROJECT=<name>
  backend "s3" {}
}

provider "aws" {
  region = local.domain.aws_region

  default_tags {
    tags = {
      domain      = local.domain.domain_name
      domain_abbr = local.domain.domain_abbr
      project     = local.config.name
      env         = var.environment
      managed_by  = "terraform"
      git_sha     = var.git_sha
      deployed_by = var.deployed_by
      repository  = var.repository
    }
  }
}
