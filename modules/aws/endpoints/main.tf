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

# VPC Endpoint for ssm
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.incoming_web_envoy_zone_subnet_ids
  security_group_ids = [var.vpc_endpoints_security_group_id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ssm-endpoint"
  }
}
