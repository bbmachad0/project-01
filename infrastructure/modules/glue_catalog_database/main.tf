# ─── Glue Catalog Database Module ────────────────────────────────
# Creates a Glue Data Catalog database.  In a Data Mesh topology
# each project typically owns three layer databases:
#   {project}_raw, {project}_refined, {project}_curated

# ─── Variables ───────────────────────────────────────────────────

variable "database_name" {
  description = "Name of the Glue Catalog database."
  type        = string
}

variable "catalog_id" {
  description = "AWS account ID (Glue Catalog ID). Defaults to caller account."
  type        = string
  default     = null
}

variable "location_uri" {
  description = "S3 location URI for the database (e.g. s3://bucket/prefix/)."
  type        = string
  default     = ""
}

variable "description" {
  description = "Human-readable database description."
  type        = string
  default     = ""
}

variable "parameters" {
  description = "Key-value parameters for the database."
  type        = map(string)
  default     = {}
}

# ─── Resource ────────────────────────────────────────────────────

resource "aws_glue_catalog_database" "this" {
  name         = var.database_name
  catalog_id   = var.catalog_id
  description  = var.description
  location_uri = var.location_uri != "" ? var.location_uri : null
  parameters   = length(var.parameters) > 0 ? var.parameters : null
}

# ─── Outputs ─────────────────────────────────────────────────────

output "database_name" {
  description = "Name of the created Glue database."
  value       = aws_glue_catalog_database.this.name
}

output "database_arn" {
  description = "ARN of the created Glue database."
  value       = aws_glue_catalog_database.this.arn
}

output "catalog_id" {
  description = "Catalog ID the database belongs to."
  value       = aws_glue_catalog_database.this.catalog_id
}
