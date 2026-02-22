# ─── Project Stack - Data Sources ────────────────────────────────
# This file is identical across all projects - do NOT customise it.
#
# Reads the shared foundation state so every project automatically
# gets the latest bucket IDs, database names, IAM ARNs, etc. without
# any variable passthrough.
# ─────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# Reads foundation outputs (S3 buckets, databases, IAM, VPC).
# The foundation state lives in the same bucket as this project state,
# under the key "infrastructure/terraform.tfstate".
data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket       = "tfstate-${data.aws_caller_identity.current.account_id}"
    key          = "infrastructure/terraform.tfstate"
    region       = local.domain.aws_region
    use_lockfile = true
  }
}
