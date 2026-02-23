# ─── Foundation - VPC ────────────────────────────────────────────
# Dedicated VPC for Glue jobs.
# Traffic to S3 and Glue API never leaves AWS (VPC endpoints in subnets.tf).

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-vpc-${var.env}"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-rt-private-${var.env}"
  })
}

# ─── VPC Flow Logs ───────────────────────────────────────────────
# Captures all traffic for auditing and anomaly investigation.

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.domain_abbr}-vpc-${var.env}/flow-logs"
  retention_in_days = 90
  tags              = local.common_tags
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "${var.domain_abbr}-vpc-flow-logs-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "vpc_flow_logs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name   = "${var.domain_abbr}-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_permissions.json
}

data "aws_iam_policy_document" "vpc_flow_logs_permissions" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-flow-log-${var.env}"
  })
}
