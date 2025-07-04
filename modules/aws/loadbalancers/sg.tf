# External Load Balancer Security Group
resource "aws_security_group" "external_lb_sg" {
  name        = "${var.stack_name}-external-lb-sg"
  description = "Security group for external-facing load balancer"
  vpc_id      = var.vpc_id

  # Ingress rules - Only allow HTTP/HTTPS from CloudFront
  ingress {
    description = "HTTP from CloudFront"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In production, use CloudFront prefix list
  }

  ingress {
    description = "HTTPS from CloudFront"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In production, use CloudFront prefix list
  }

  # No egress rules here - will be added as specific rules

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-external-lb-sg"
  })
}


# Squid Internal Load Balancer Security Group
resource "aws_security_group" "squid_internal_lb_sg" {
  name                   = "${var.stack_name}-squid-internal-lb-sg"
  description            = "Security group for Squid internal ALB"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = {
    Name = "${var.stack_name}-squid-internal-lb-sg"
  }
}
