# ─── Project Template ────────────────────────────────────────────
# The quickest way to add a project is:
#
#   make new-project NAME=<my_project> SLUG=<short_id>
#
# That copies this template, sets the slug in project.json, and prints
# next steps.  Or do it manually:
#
#   1. cp -r infrastructure/projects/_template infrastructure/projects/<my_project>
#   2. Edit project.json  - set "slug" to a short unique id (e.g. "sales")
#   3. Edit tables.tf     - define your Glue Data Catalog tables
#   4. Edit jobs.tf       - define your Glue Jobs
#   5. Edit optimizers.tf - wire table optimizers (if not using glue_iceberg_table)
#   6. Edit pipelines.tf  - compose jobs into StepFunction pipelines
#   7. Commit and push    - CI/CD auto-discovers the new directory
#
# NO changes to any central file (main.tf, variables.tf, etc.) are needed.
# Each project is an independent Terraform root module with its own
# remote state.  Foundation outputs (buckets, databases, IAM) are consumed
# automatically via terraform_remote_state.
#
# Available locals (use in tables.tf / jobs.tf / pipelines.tf):
#   local.config.slug                     → this project's slug
#   local.foundation.s3_raw_bucket_id     → raw layer bucket
#   local.foundation.s3_refined_bucket_id → refined layer bucket
#   local.foundation.s3_curated_bucket_id → curated layer bucket
#   local.foundation.s3_artifacts_bucket_id
#   local.foundation.db_raw_name
#   local.foundation.db_refined_name
#   local.foundation.db_curated_name
#   local.foundation.sfn_execution_role_arn
#   local.foundation.glue_connection_name
#   local.foundation.domain_abbr
#   data.aws_caller_identity.current.account_id
#   var.environment
#
# Hierarchy:  Domain (this repo) > Project (this directory) > Resources
# ─────────────────────────────────────────────────────────────────
