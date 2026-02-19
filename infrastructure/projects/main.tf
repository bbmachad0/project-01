# ─── Projects Aggregator ─────────────────────────────────────────
# Wires all projects in this domain.
#
# Hierarchy:  Domain (this repo) > Project (subdirectory) > Resources
#
# Each project receives `domain_abbr` (shared) and a unique
# `project_slug` that prevents naming collisions in AWS.
#
# To add a new project:
#   1. cp -r projects/_template projects/<my_project>
#   2. Fill in tables.tf, jobs.tf, optimizers.tf, pipelines.tf
#   3. Add a module block below with a unique project_slug
# ─────────────────────────────────────────────────────────────────

locals {
  # Common inputs passed to every project stack (minus project_slug).
  shared = {
    domain_abbr            = var.domain_abbr
    env                    = var.env
    account_id             = var.account_id
    region                 = var.region
    artifacts_bucket       = var.artifacts_bucket
    raw_bucket             = var.raw_bucket
    refined_bucket         = var.refined_bucket
    curated_bucket         = var.curated_bucket
    sfn_execution_role_arn = var.sfn_execution_role_arn
    db_raw_name            = var.db_raw_name
    db_refined_name        = var.db_refined_name
    db_curated_name        = var.db_curated_name
    common_tags            = var.common_tags
  }
}

# ─── Project: Project01 ──────────────────────────────────────────────

module "project01" {
  source = "./project01"

  domain_abbr            = local.shared.domain_abbr
  project_slug           = "pj01"
  env                    = local.shared.env
  account_id             = local.shared.account_id
  region                 = local.shared.region
  artifacts_bucket       = local.shared.artifacts_bucket
  raw_bucket             = local.shared.raw_bucket
  refined_bucket         = local.shared.refined_bucket
  curated_bucket         = local.shared.curated_bucket
  sfn_execution_role_arn = local.shared.sfn_execution_role_arn
  db_raw_name            = local.shared.db_raw_name
  db_refined_name        = local.shared.db_refined_name
  db_curated_name        = local.shared.db_curated_name
  common_tags            = local.shared.common_tags
}
