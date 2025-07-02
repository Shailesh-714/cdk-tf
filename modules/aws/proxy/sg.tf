# Envoy Proxy Security Group
resource "aws_security_group" "envoy_sg" {
  name        = "${var.stack_name}-envoy-sg"
  description = "Security group for Envoy proxy instances"
  vpc_id      = var.vpc_id

  # Allow HTTPS to S3
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS to S3 (via VPC Gateway Endpoint)"
  }

  # Allow DNS UDP
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow DNS UDP"
  }

  # Allow DNS TCP
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow DNS TCP"
  }

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-envoy-sg"
  })
}

# External LB -> Envoy (egress)
resource "aws_security_group_rule" "external_lb_to_envoy_egress" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.envoy_sg.id
  security_group_id        = var.external_alb_security_group_id
  description              = "Allow traffic to Envoy proxy"
}

# External LB -> Envoy (ingress)
resource "aws_security_group_rule" "envoy_from_external_lb_ingress" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = var.external_alb_security_group_id
  security_group_id        = aws_security_group.envoy_sg.id
  description              = "Allow traffic from External LB"
}

# Envoy -> Internal LB (egress)
resource "aws_security_group_rule" "envoy_to_internal_lb_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.internal_alb_security_group_id
  security_group_id        = aws_security_group.envoy_sg.id
  description              = "Allow traffic to Internal LB"
}

# Envoy -> Internal LB (ingress)
resource "aws_security_group_rule" "internal_lb_from_envoy_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.envoy_sg.id
  security_group_id        = var.internal_alb_security_group_id
  description              = "Allow traffic from Envoy"
}
