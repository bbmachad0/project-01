module "pipeline_main" {
  source = "../../modules/stepfunction_pipeline"

  pipeline_name  = "${var.domain_abbr}-${var.project_slug}-pipeline-main-${var.env}"
  role_arn       = var.sfn_execution_role_arn
  glue_job_names = [
    module.job_job01.job_name,
    module.job_job02.job_name,
  ]

  tags = var.common_tags
}