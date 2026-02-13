# ─── IAM Role Module ─────────────────────────────────────────────
# Creates an IAM role with an assume-role policy and attaches
# a list of managed or inline policies.

variable "role_name" {
  description = "IAM role name."
  type        = string
}

variable "assume_role_service" {
  description = "AWS service principal that can assume this role (e.g. glue.amazonaws.com)."
  type        = string
}

variable "managed_policy_arns" {
  description = "List of managed IAM policy ARNs to attach."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Optional inline policy document (JSON)."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

# ─── Data ────────────────────────────────────────────────────────

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [var.assume_role_service]
    }
  }
}

# ─── Resources ───────────────────────────────────────────────────

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  count      = length(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = var.managed_policy_arns[count.index]
}

resource "aws_iam_role_policy" "inline" {
  count  = var.inline_policy_json != "" ? 1 : 0
  name   = "${var.role_name}-inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

# ─── Outputs ─────────────────────────────────────────────────────

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "role_name" {
  value = aws_iam_role.this.name
}

output "role_id" {
  value = aws_iam_role.this.id
}
