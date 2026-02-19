# ─── Dev Environment - Root Module ───────────────────────────────
# Reads domain config from the repository-root domain.json file.
# Backend is configured via partial config (see backend.conf).\

locals {
  domain = jsondecode(file("${path.module}/../../../domain.json"))
  env    = "dev"
}

terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
    }
  }
}

# ─── Foundation Infrastructure ───────────────────────────────────

module "foundation" {
  source      = "../../foundation"
  domain_name = local.domain.domain_name
  domain_abbr = local.domain.domain_abbr
  env         = local.env
  aws_region  = local.domain.aws_region
  vpc_cidr    = "10.10.0.0/16"
}

# ─── Projects ────────────────────────────────────────────────────

module "projects" {
  source      = "../../projects"
  domain_abbr = local.domain.domain_abbr
  env         = local.env

  account_id               = module.foundation.account_id
  region                   = module.foundation.region
  artifacts_bucket         = module.foundation.s3_artifacts_bucket_id
  raw_bucket               = module.foundation.s3_raw_bucket_id
  curated_bucket           = module.foundation.s3_curated_bucket_id
  warehouse_bucket         = module.foundation.s3_warehouse_bucket_id
  sfn_execution_role_arn   = module.foundation.sfn_execution_role_arn

  db_raw_name     = module.foundation.db_raw_name
  db_refined_name = module.foundation.db_refined_name
  db_curated_name = module.foundation.db_curated_name

  common_tags = {
    domain      = local.domain.domain_name
    domain_abbr = local.domain.domain_abbr
    env         = local.env
    managed_by  = "terraform"
  }
}
