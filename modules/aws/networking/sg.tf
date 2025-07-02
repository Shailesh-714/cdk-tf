# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.stack_name}-vpce-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for VPC Endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-vpce-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
