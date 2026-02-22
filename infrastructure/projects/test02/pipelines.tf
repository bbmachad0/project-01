module "pipeline_main" {
  source = "../../modules/stepfunction_pipeline"

  pipeline_name  = "${local.foundation.domain_abbr}-${local.config.slug}-pipeline-main-${var.environment}"
  role_arn       = local.foundation.sfn_execution_role_arn
  glue_job_names = [
    module.job_job01.job_name,
    module.job_job02.job_name,
  ]

  tags = local.tags
}