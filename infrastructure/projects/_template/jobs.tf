# ─── Glue Jobs ───────────────────────────────────────────────────
# Define Glue Jobs for this project.
#
# Naming convention:  {domain_abbr}-{project_name}-{job_name}-{env}
# Example:            f01-sales-ingest-events-dev
#
# Each job reads from / writes to the tables defined in tables.tf.
#
# Example:
#
#   module "job_ingest_events" {
#     source = "../../modules/glue_job"
#
#     job_name    = "${local.baseline.domain_abbr}-${local.config.name}-ingest-events-${var.environment}"
#     description = "Ingest raw events from source into RAW layer."
#     role_arn    = module.iam_glue_job.role_arn
#
#     script_s3_path    = "s3://${local.baseline.s3_artifacts_bucket_id}/jobs/<folder>/job_ingest_events.py"
#     extra_py_files    = "s3://${local.baseline.s3_artifacts_bucket_id}/wheels/data_platform_foundation-${var.wheel_version}-py3-none-any.whl"
#     temp_dir          = "s3://${local.baseline.s3_artifacts_bucket_id}/glue-temp/"
#     iceberg_warehouse = "s3://${local.baseline.s3_curated_bucket_id}/${local.config.name}/"
#
#     worker_type       = "G.1X"
#     number_of_workers = 2
#     timeout_minutes   = 60
#     bookmark_enabled  = true
#     connections       = [local.baseline.glue_connection_name]   # VPC isolation
#
#     default_arguments = {
#       "--ENV" = var.environment
#     }
#
#     tags = local.tags
#   }
