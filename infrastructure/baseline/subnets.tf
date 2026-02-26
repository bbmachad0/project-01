# ─── Baseline - Private Subnets & Network ────────────────────────
# Glue jobs run inside private subnets.
# Subnet CIDRs are derived automatically from var.vpc_cidr (DRY).
# S3 and Glue API traffic stays inside AWS via VPC endpoints.

locals {
  # Auto-derive 3 /24 private subnets from the VPC CIDR.
  # e.g. vpc 10.10.0.0/16 → 10.10.1.0/24, 10.10.2.0/24, 10.10.3.0/24
  private_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2),
    cidrsubnet(var.vpc_cidr, 8, 3),
  ]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private" {
  count             = length(local.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-subnet-private-${count.index}-${var.env}"
    Tier = "private"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ─── S3 Gateway Endpoint ─────────────────────────────────────────
# Free endpoint - S3 traffic stays in the AWS network.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private.id]

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-vpce-s3-${var.env}"
  })
}

# ─── Glue API Interface Endpoint ─────────────────────────────────
# Allows Glue workers to call the Glue API without leaving the VPC.

resource "aws_security_group" "glue_endpoint" {
  name_prefix = "${var.domain_abbr}-glue-vpce-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for the Glue API Interface VPC endpoint."

  ingress {
    description = "HTTPS from within VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-sg-glue-vpce-${var.env}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "glue" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.glue"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true

  security_group_ids = [aws_security_group.glue_endpoint.id]

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-vpce-glue-${var.env}"
  })
}

# ─── STS Interface Endpoint ──────────────────────────────────────
# Required: settings.py calls sts:GetCallerIdentity to resolve the
# account ID for bucket naming.  Without this endpoint the call
# times out in the private-only VPC.

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true

  security_group_ids = [aws_security_group.glue_endpoint.id]

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-vpce-sts-${var.env}"
  })
}

# ─── CloudWatch Logs Interface Endpoint ──────────────────────────
# Future-proofing: explicit boto3 CloudWatch Logs calls (e.g. custom
# metrics, log queries) and any dp_foundation library extensions will need
# this endpoint in the NAT-less VPC.

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true

  security_group_ids = [aws_security_group.glue_endpoint.id]

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-vpce-logs-${var.env}"
  })
}

# ─── Glue Job Security Group ─────────────────────────────────────
# Glue workers shuffle data between each other (requires self-reference).
# Outbound reaches S3 via the Gateway endpoint and Glue API via the
# Interface endpoint - no internet egress needed.

resource "aws_security_group" "glue_job" {
  name_prefix = "${var.domain_abbr}-glue-job-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for AWS Glue job worker nodes."

  ingress {
    description = "Glue worker shuffle traffic (self)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Glue worker shuffle traffic (self)"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "HTTPS to VPC endpoints (S3, Glue)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${var.domain_abbr}-sg-glue-job-${var.env}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ─── Glue Network Connection ─────────────────────────────────────
# One domain-level connection shared by all Glue jobs.
# Jobs reference it by name: connections = [var.glue_connection_name]

resource "aws_glue_connection" "main" {
  name        = "${var.domain_abbr}-vpc-${var.env}"
  description = "Domain VPC connection for all Glue jobs."

  connection_type = "NETWORK"

  physical_connection_requirements {
    availability_zone      = aws_subnet.private[0].availability_zone
    subnet_id              = aws_subnet.private[0].id
    security_group_id_list = [aws_security_group.glue_job.id]
  }

  tags = local.common_tags
}
#}
