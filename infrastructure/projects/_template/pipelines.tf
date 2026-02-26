# ─── Pipelines (Orchestration) ───────────────────────────────────
# Compose Glue Jobs into Step Functions state machines.
#
# Naming convention:  {domain_abbr}-{project_name}-pipeline-{name}-{env}
# Example:            f01-sales-pipeline-ingest-dev
#
# Example:
#
#   module "pipeline_ingest" {
#     source = "../../modules/stepfunction_pipeline"
#
#     pipeline_name  = "${local.baseline.domain_abbr}-${local.config.name}-pipeline-ingest-${var.environment}"
#     role_arn       = local.baseline.sfn_execution_role_arn
#     glue_job_names = [
#       module.job_ingest_events.job_name,
#       module.job_transform.job_name,
#     ]
#     kms_key_arn = local.baseline.kms_key_arn   # encrypts the pipeline log group
#     tags = local.tags
#   }
