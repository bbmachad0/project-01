# ─── Project: Sales — Glue Jobs ──────────────────────────────────

module "job_daily_sales" {
  source = "../../modules/glue_job"

  job_name    = "${var.domain_abbr}-${var.project_slug}-daily-sales-${var.env}"
  description = "Aggregate raw sales events into daily summaries."
  role_arn    = var.glue_execution_role_arn

  script_s3_path    = "s3://${var.artifacts_bucket}/jobs/sales/job_daily_sales.py"
  extra_py_files    = "s3://${var.artifacts_bucket}/wheels/core-latest-py3-none-any.whl"
  temp_dir          = "s3://${var.artifacts_bucket}/glue-temp/"
  iceberg_warehouse = "s3://${var.warehouse_bucket}/iceberg/"

  worker_type       = "G.1X"
  number_of_workers = 4
  timeout_minutes   = 60
  bookmark_enabled  = true

  default_arguments = {
    "--ENV" = var.env
  }

  tags = var.common_tags
}
