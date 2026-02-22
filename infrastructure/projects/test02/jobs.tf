module "job_job01" {
  source = "../../modules/glue_job"

  job_name    = "${local.foundation.domain_abbr}-${local.config.slug}-job01-${var.environment}"
  description = "Ingest raw events e escreve em refined."
  role_arn    = module.iam_glue_job.role_arn

  script_s3_path    = "s3://${local.foundation.s3_artifacts_bucket_id}/jobs/test02/job_job01.py"
  extra_py_files    = "s3://${local.foundation.s3_artifacts_bucket_id}/wheels/core-latest-py3-none-any.whl"
  temp_dir          = "s3://${local.foundation.s3_artifacts_bucket_id}/glue-temp/"
  iceberg_warehouse = "s3://${local.foundation.s3_refined_bucket_id}/${local.config.slug}/"

  worker_type       = "G.1X"
  number_of_workers = 2
  timeout_minutes   = 60
  bookmark_enabled  = true
  connections       = [local.foundation.glue_connection_name]

  default_arguments = {
    "--ENV" = var.environment
  }

  tags = local.tags
}

module "job_job02" {
  source = "../../modules/glue_job"

  job_name    = "${local.foundation.domain_abbr}-${local.config.slug}-job02-${var.environment}"
  description = "Agrega refined e escreve em curated."
  role_arn    = module.iam_glue_job.role_arn

  script_s3_path    = "s3://${local.foundation.s3_artifacts_bucket_id}/jobs/test02/job_job02.py"
  extra_py_files    = "s3://${local.foundation.s3_artifacts_bucket_id}/wheels/core-latest-py3-none-any.whl"
  temp_dir          = "s3://${local.foundation.s3_artifacts_bucket_id}/glue-temp/"
  iceberg_warehouse = "s3://${local.foundation.s3_curated_bucket_id}/${local.config.slug}/"

  worker_type       = "G.1X"
  number_of_workers = 2
  timeout_minutes   = 60
  bookmark_enabled  = false
  connections       = [local.foundation.glue_connection_name]

  default_arguments = {
    "--ENV" = var.environment
  }

  tags = local.tags
}