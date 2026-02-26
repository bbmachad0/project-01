# ─── Dev Environment - Root Module ───────────────────────────────
# Reads domain config from the repository-root domain.json file.
# Backend is configured via partial config (see backend.conf).\

locals {
  domain = jsondecode(file("${path.module}/../../../setup/domain.json"))
  env    = "dev"
}

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

  backend "s3" {
    key     = "infrastructure/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = local.domain.aws_region

  default_tags {
    tags = {
      domain      = local.domain.domain_name
      domain_abbr = local.domain.domain_abbr
      env         = local.env
      managed_by  = "terraform"
      git_sha     = var.git_sha
      deployed_by = var.deployed_by
      repository  = var.repository
    }
  }
}

# ─── Traceability Variables ──────────────────────────────────────────
# Set via TF_VAR_* in CI (git_sha, deployed_by, repository).
# Default to "local" for local development runs.

variable "git_sha" {
  description = "Git commit SHA injected at deploy time (TF_VAR_git_sha)."
  type        = string
  default     = "local"
}

variable "deployed_by" {
  description = "CI actor or 'local'. Injected via TF_VAR_deployed_by."
  type        = string
  default     = "local"
}

variable "repository" {
  description = "Source repository. Injected via TF_VAR_repository."
  type        = string
  default     = "local"
}

# ─── Baseline Infrastructure ───────────────────────────────────────

module "baseline" {
  source       = "../../baseline"
  domain_name  = local.domain.domain_name
  domain_abbr  = local.domain.domain_abbr
  country_code = local.domain.country_code
  env          = local.env
  aws_region   = local.domain.aws_region
  vpc_cidr     = "10.10.0.0/16"
}

# Projects are now independent Terraform root modules under
# infrastructure/projects/<name>/ - each has its own remote state.
# See docs/adding-a-job.md or run: make new-project NAME=<name>
