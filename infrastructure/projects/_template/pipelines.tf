# ─── Pipelines (Orchestration) ───────────────────────────────────
# Compose Glue Jobs into Step Functions state machines.
#
# Naming convention:  {domain_abbr}-{project_slug}-pipeline-{name}-{env}
# Example:            nl-sales-pipeline-ingest-dev
#
# Example:
#
#   module "pipeline_ingest" {
#     source = "../../modules/stepfunction_pipeline"
#
#     pipeline_name  = "${var.domain_abbr}-${var.project_slug}-pipeline-ingest-${var.env}"
#     role_arn       = var.sfn_execution_role_arn
#     glue_job_names = [
#       module.job_ingest_events.job_name,
#       module.job_transform.job_name,
#     ]
#     tags = var.common_tags
#   }
