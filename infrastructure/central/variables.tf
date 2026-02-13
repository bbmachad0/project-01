# ─── Central Infrastructure — Variables & Locals ────────────────

variable "project" {
  description = "Project / domain identifier used for naming."
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
    project     = var.project
    env         = var.env
    managed_by  = "terraform"
    domain      = "data-mesh"
  }
}
