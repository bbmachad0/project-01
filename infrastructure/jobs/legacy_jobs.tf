# ─── Legacy Refactor — Glue Jobs ─────────────────────────────────

module "job_legacy_step01" {
  source = "../modules/glue_job"

  job_name    = "${var.project}-legacy-step01-${var.env}"
  description = "Legacy migration step 01 — schema alignment and ingestion."
  role_arn    = var.glue_execution_role_arn

  script_s3_path = "s3://${var.artifacts_bucket}/jobs/legacy_refactor/job_step01.py"
  extra_py_files = "s3://${var.artifacts_bucket}/wheels/domain_project-latest-py3-none-any.whl"

  worker_type       = "G.2X"
  number_of_workers = 6
  timeout_minutes   = 120

  default_arguments = {
    "--ENV" = var.env
  }

  tags = var.common_tags
}

# ─── Legacy Pipeline (StepFunction) ─────────────────────────────

module "pipeline_legacy" {
  source = "../modules/stepfunction_pipeline"

  pipeline_name  = "${var.project}-pipeline-legacy-${var.env}"
  role_arn       = var.sfn_execution_role_arn
  glue_job_names = [module.job_legacy_step01.job_name]
  tags           = var.common_tags
}
