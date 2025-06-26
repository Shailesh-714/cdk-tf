# ==========================================================
#                      VPC Endpoints
# ==========================================================

# AWS Region
data "aws_region" "current" {}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  route_table_ids = concat(
    [var.isolated_route_table_id],
    var.private_with_nat_route_table_ids
  )

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-s3-endpoint"

    }
  )
}

# VPC Endpoint for SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids["incoming_web_envoy_zone"]
  security_group_ids = [var.vpc_endpoints_security_group_id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ssm-endpoint"
  }
}

# VPC Endpoint for SSM Messages
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids["incoming_web_envoy_zone"]
  security_group_ids = [var.vpc_endpoints_security_group_id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ssmmessages-endpoint"
  }
}

# VPC Endpoint for EC2 Messages
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids["incoming_web_envoy_zone"]
  security_group_ids = [var.vpc_endpoints_security_group_id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ec2messages-endpoint"
  }
}

# VPC Endpoint for Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids["locker_database_zone"]
  security_group_ids = [var.vpc_endpoints_security_group_id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-secretsmanager-endpoint"
  }
}

# VPC Endpoint for KMS
resource "aws_vpc_endpoint" "kms" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.kms"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids["database_zone"]
  security_group_ids = [var.vpc_endpoints_security_group_id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-kms-endpoint"
  }
}

# VPC Endpoint for RDS
resource "aws_vpc_endpoint" "rds" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.rds"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.subnet_ids["database_zone"]
  security_group_ids = [var.vpc_endpoints_security_group_id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-rds-endpoint"
  }
}
