# ─── Project Stack - Variables ───────────────────────────────────
# Only ONE variable is needed here. Everything else (buckets, databases,
# IAM ARNs, etc.) is read automatically from the foundation remote state.
#
# The project slug lives in project.json (local.config.slug), so you
# do NOT need to pass it as a Terraform variable.
# ─────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment (dev, int, prod)."
  type        = string
}
