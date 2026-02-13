# ─── Int Environment — Root Module ───────────────────────────────

terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "domain-project-tfstate-int"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "domain-project-tflock-int"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project    = var.project
      env        = "int"
      managed_by = "terraform"
    }
  }
}

# ─── Variables ───────────────────────────────────────────────────

variable "project" {
  type    = string
  default = "domain-project"
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

# ─── Central Infrastructure ─────────────────────────────────────

module "central" {
  source     = "../../central"
  project    = var.project
  env        = "int"
  aws_region = var.aws_region
  vpc_cidr   = "10.20.0.0/16"
}

# ─── Jobs ────────────────────────────────────────────────────────

module "jobs" {
  source                  = "../../jobs"
  project                 = var.project
  env                     = "int"
  artifacts_bucket        = module.central.s3_artifacts_bucket_id
  glue_execution_role_arn = module.central.glue_execution_role_arn
  sfn_execution_role_arn  = module.central.sfn_execution_role_arn

  common_tags = {
    project    = var.project
    env        = "int"
    managed_by = "terraform"
  }
}
