# ─── Glue Jobs ───────────────────────────────────────────────────
# Define Glue Jobs for this project.
#
# Naming convention:  {domain_abbr}-{project_slug}-{job_name}-{env}
# Example:            f01-pj01-ingest-events-dev
#
# Each job reads from / writes to the tables defined in tables.tf.
#
# Example:
#
#   module "job_ingest_events" {
#     source = "../../modules/glue_job"
#
#     job_name    = "${var.domain_abbr}-${var.project_slug}-ingest-events-${var.env}"
#     description = "Ingest raw events from source into RAW layer."
#     role_arn    = module.iam_glue_job.role_arn
#
#     script_s3_path    = "s3://${var.artifacts_bucket}/jobs/<folder>/job_ingest_events.py"
#     extra_py_files    = "s3://${var.artifacts_bucket}/wheels/core-latest-py3-none-any.whl"
#     temp_dir          = "s3://${var.artifacts_bucket}/glue-temp/"
#     iceberg_warehouse = "s3://${var.warehouse_bucket}/${var.project_slug}/"
#
#     worker_type       = "G.1X"
#     number_of_workers = 2
#     timeout_minutes   = 60
#     bookmark_enabled  = true
#
#     default_arguments = {
#       "--ENV" = var.env
#     }
#
#     tags = var.common_tags
#   }
