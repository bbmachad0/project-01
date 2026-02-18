# ─── Project: Legacy Refactor — Glue Jobs ────────────────────────

module "job_legacy_step01" {
  source = "../../modules/glue_job"

  job_name    = "${var.domain_abbr}-${var.project_slug}-step01-${var.env}"
  description = "Legacy migration — schema alignment and ingestion into Iceberg."
  role_arn    = var.glue_execution_role_arn

  script_s3_path    = "s3://${var.artifacts_bucket}/jobs/legacy_refactor/job_step01.py"
  extra_py_files    = "s3://${var.artifacts_bucket}/wheels/core-latest-py3-none-any.whl"
  temp_dir          = "s3://${var.artifacts_bucket}/glue-temp/"
  iceberg_warehouse = "s3://${var.warehouse_bucket}/iceberg/"

  worker_type       = "G.2X"
  number_of_workers = 6
  timeout_minutes   = 120

  default_arguments = {
    "--ENV" = var.env
  }

  tags = var.common_tags
}
