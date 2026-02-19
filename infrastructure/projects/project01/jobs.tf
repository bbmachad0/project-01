module "job_teste" {
  source = "../../modules/glue_job"

  job_name          = "${var.domain_abbr}-${var.project_slug}-teste-${var.env}"
  description       = "Job teste do projeto project01."
  role_arn          = module.iam_glue_job.role_arn
  script_s3_path    = "s3://${var.artifacts_bucket}/jobs/project01/job_teste.py"
  extra_py_files    = "s3://${var.artifacts_bucket}/wheels/core-latest-py3-none-any.whl"
  temp_dir          = "s3://${var.artifacts_bucket}/glue-temp/"
  iceberg_warehouse = "s3://${var.curated_bucket}/${var.project_slug}/"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout_minutes   = 60
  bookmark_enabled  = true

  default_arguments = {
    "--ENV" = var.env
  }

  tags = var.common_tags
}