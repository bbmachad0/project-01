# ─── Project Stack - Locals ──────────────────────────────────────
# This file is identical across all projects - do NOT customise it.
#
# Provides three key locals used throughout the project stack:
#   local.domain   → domain config from setup/domain.json
#   local.config   → project config from this directory's project.json
#   local.baseline → all outputs from the shared baseline stack
# ─────────────────────────────────────────────────────────────────

locals {
  # Domain-level configuration (single source of truth for the whole repo).
  domain = jsondecode(file("${path.module}/../../../setup/domain.json"))

  # Per-project configuration.  The only file you change when copying _template.
  config = jsondecode(file("${path.module}/project.json"))

  # All outputs from the shared baseline stack (S3 buckets, databases, IAM, VPC).
  baseline = data.terraform_remote_state.baseline.outputs

  # Extra tags to merge on resources in this project (provider default_tags handle
  # the standard ones; add project-specific overrides here if needed).
  tags = {}
}
