# ─── Project: Customers — Pipelines ──────────────────────────────

module "pipeline_customers" {
  source = "../../modules/stepfunction_pipeline"

  pipeline_name  = "${var.domain_abbr}-${var.project_slug}-pipeline-${var.env}"
  role_arn       = var.sfn_execution_role_arn
  glue_job_names = [module.job_customer_delta.job_name]
  tags           = var.common_tags
}
