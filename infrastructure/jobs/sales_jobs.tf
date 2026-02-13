# ─── Sales Domain — Glue Jobs ────────────────────────────────────

module "job_daily_sales" {
  source = "../modules/glue_job"

  job_name    = "${var.project}-sales-daily-sales-${var.env}"
  description = "Aggregate raw sales events into daily summaries."
  role_arn    = var.glue_execution_role_arn

  script_s3_path = "s3://${var.artifacts_bucket}/jobs/sales/job_daily_sales.py"
  extra_py_files = "s3://${var.artifacts_bucket}/wheels/domain_project-latest-py3-none-any.whl"

  worker_type       = "G.1X"
  number_of_workers = 4
  timeout_minutes   = 60
  bookmark_enabled  = true

  default_arguments = {
    "--ENV" = var.env
  }

  tags = var.common_tags
}

# ─── Sales Pipeline (StepFunction) ──────────────────────────────

module "pipeline_sales" {
  source = "../modules/stepfunction_pipeline"

  pipeline_name  = "${var.project}-pipeline-sales-${var.env}"
  role_arn       = var.sfn_execution_role_arn
  glue_job_names = [module.job_daily_sales.job_name]
  tags           = var.common_tags
}
