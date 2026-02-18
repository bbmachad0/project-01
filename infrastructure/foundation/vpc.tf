# ─── Foundation — VPC ────────────────────────────────────────────
# Dedicated VPC for Glue jobs that require VPC connectivity
# (e.g., RDS, Redshift, or on-prem data sources via Direct Connect).

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-vpc-${var.env}"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-igw-${var.env}"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-rt-private-${var.env}"
  })
}
