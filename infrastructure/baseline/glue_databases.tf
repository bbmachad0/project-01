# ─── Baseline - Glue Catalog Databases ───────────────────────────
# Domain-scoped databases following a three-layer data-lake model:
#
#   {domain_abbr}_{country_code}_raw      - ingested data, as-is from sources
#   {domain_abbr}_{country_code}_refined  - cleansed, conformed, business-typed
#   {domain_abbr}_{country_code}_curated  - analytics-ready Iceberg tables
#
# The country_code (ISO 3166-1 alpha-2) distinguishes databases when
# queried cross-region via Amazon Athena.
#
# The "default" database is NOT created here - it already exists in
# every AWS account and is required by Iceberg for internal metadata.

module "db_raw" {
  source        = "../modules/glue_catalog_database"
  database_name = "${local.db_prefix}_raw"
  location_uri  = "s3://${module.s3_raw.bucket_id}/"
  description   = "Raw layer - ingested data as-is from source systems."
}

module "db_refined" {
  source        = "../modules/glue_catalog_database"
  database_name = "${local.db_prefix}_refined"
  location_uri  = "s3://${module.s3_refined.bucket_id}/"
  description   = "Refined layer - cleansed and conformed data."
}

module "db_curated" {
  source        = "../modules/glue_catalog_database"
  database_name = "${local.db_prefix}_curated"
  location_uri  = "s3://${module.s3_curated.bucket_id}/"
  description   = "Curated layer - business-ready Iceberg tables."
}
