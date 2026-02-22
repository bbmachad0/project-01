module "job_teste" {
  source = "../../modules/glue_job"

  job_name          = "${local.foundation.domain_abbr}-${local.config.slug}-teste-${var.environment}"
  description       = "Job teste do projeto project01."
  role_arn          = module.iam_glue_job.role_arn
  script_s3_path    = "s3://${local.foundation.s3_artifacts_bucket_id}/jobs/project01/job_teste.py"
  extra_py_files    = "s3://${local.foundation.s3_artifacts_bucket_id}/wheels/core-latest-py3-none-any.whl"
  temp_dir          = "s3://${local.foundation.s3_artifacts_bucket_id}/glue-temp/"
  iceberg_warehouse = "s3://${local.foundation.s3_curated_bucket_id}/${local.config.slug}/"
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