# ─── Project Stack - Variables ───────────────────────────────────
# Only ONE variable is needed here. Everything else (buckets, databases,
# IAM ARNs, etc.) is read automatically from the baseline remote state.
#
# The project name lives in project.json (local.config.name), so you
# do NOT need to pass it as a Terraform variable.
# ─────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment (dev, int, prod)."
  type        = string
}
# ─── Traceability Variables ──────────────────────────────────────────
# Set via TF_VAR_* in CI. Default to "local" for local development runs.

variable "git_sha" {
  description = "Git commit SHA injected at deploy time (TF_VAR_git_sha)."
  type        = string
  default     = "local"
}

variable "deployed_by" {
  description = "CI actor or 'local'. Injected via TF_VAR_deployed_by."
  type        = string
  default     = "local"
}

variable "repository" {
  description = "Source repository. Injected via TF_VAR_repository."
  type        = string
  default     = "local"
}

variable "wheel_version" {
  description = "Version of the data-platform-foundation wheel (e.g. 1.0.0). Injected via TF_VAR_wheel_version in CI."
  type        = string
  default     = "1.0.0"
}