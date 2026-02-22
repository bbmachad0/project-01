module "job_job01" {
  source = "../../modules/glue_job"

  job_name    = "${var.domain_abbr}-${var.project_slug}-job01-${var.env}"
  description = "Ingest raw events e escreve em refined."
  role_arn    = module.iam_glue_job.role_arn

  script_s3_path    = "s3://${var.artifacts_bucket}/jobs/test02/job_job01.py"
  extra_py_files    = "s3://${var.artifacts_bucket}/wheels/core-latest-py3-none-any.whl"
  temp_dir          = "s3://${var.artifacts_bucket}/glue-temp/"
  iceberg_warehouse = "s3://${var.refined_bucket}/${var.project_slug}/"

  worker_type       = "G.1X"
  number_of_workers = 2
  timeout_minutes   = 60
  bookmark_enabled  = true

  default_arguments = {
    "--ENV" = var.env
  }

  tags = var.common_tags
}

module "job_job02" {
  source = "../../modules/glue_job"

  job_name    = "${var.domain_abbr}-${var.project_slug}-job02-${var.env}"
  description = "Agrega refined e escreve em curated."
  role_arn    = module.iam_glue_job.role_arn

  script_s3_path    = "s3://${var.artifacts_bucket}/jobs/test02/job_job02.py"
  extra_py_files    = "s3://${var.artifacts_bucket}/wheels/core-latest-py3-none-any.whl"
  temp_dir          = "s3://${var.artifacts_bucket}/glue-temp/"
  iceberg_warehouse = "s3://${var.curated_bucket}/${var.project_slug}/"

  worker_type       = "G.1X"
  number_of_workers = 2
  timeout_minutes   = 60
  bookmark_enabled  = false

  default_arguments = {
    "--ENV" = var.env
  }

  tags = var.common_tags
}