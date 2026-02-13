# ─── Customer Domain — Glue Jobs ─────────────────────────────────

module "job_customer_delta" {
  source = "../modules/glue_job"

  job_name    = "${var.project}-customers-customer-delta-${var.env}"
  description = "Merge incremental customer CDC events into curated Iceberg table."
  role_arn    = var.glue_execution_role_arn

  script_s3_path = "s3://${var.artifacts_bucket}/jobs/customers/job_customer_delta.py"
  extra_py_files = "s3://${var.artifacts_bucket}/wheels/domain_project-latest-py3-none-any.whl"

  worker_type       = "G.1X"
  number_of_workers = 2
  timeout_minutes   = 45
  bookmark_enabled  = true

  default_arguments = {
    "--ENV" = var.env
  }

  tags = var.common_tags
}

# ─── Customer Pipeline (StepFunction) ───────────────────────────

module "pipeline_customers" {
  source = "../modules/stepfunction_pipeline"

  pipeline_name  = "${var.project}-pipeline-customers-${var.env}"
  role_arn       = var.sfn_execution_role_arn
  glue_job_names = [module.job_customer_delta.job_name]
  tags           = var.common_tags
}
