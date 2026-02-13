# ─── Central Infrastructure — Outputs ────────────────────────────

output "s3_raw_bucket_arn" {
  value = module.s3_raw.bucket_arn
}

output "s3_curated_bucket_arn" {
  value = module.s3_curated.bucket_arn
}

output "s3_warehouse_bucket_arn" {
  value = module.s3_warehouse.bucket_arn
}

output "s3_artifacts_bucket_arn" {
  value = module.s3_artifacts.bucket_arn
}

output "s3_artifacts_bucket_id" {
  value = module.s3_artifacts.bucket_id
}

output "glue_execution_role_arn" {
  value = module.glue_execution_role.role_arn
}

output "sfn_execution_role_arn" {
  value = module.sfn_execution_role.role_arn
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
