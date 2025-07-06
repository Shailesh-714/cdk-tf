# Envoy Proxy Security Group
resource "aws_security_group" "envoy_sg" {
  name        = "${var.stack_name}-envoy-sg"
  description = "Security group for Envoy proxy instances"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-envoy-sg"
  })
}

# HTTPS to S3
resource "aws_security_group_rule" "envoy_https_s3" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.envoy_sg.id
  description       = "Allow HTTPS to S3"
}

# DNS UDP
resource "aws_security_group_rule" "envoy_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.envoy_sg.id
  description       = "Allow DNS UDP"
}

# DNS TCP
resource "aws_security_group_rule" "envoy_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.envoy_sg.id
  description       = "Allow DNS TCP"
}

# External LB -> Envoy (egress)
resource "aws_security_group_rule" "external_lb_to_envoy_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.envoy_sg.id
  security_group_id        = var.external_alb_security_group_id
  description              = "Allow traffic to Envoy proxy"
}

# External LB -> Envoy (ingress)
resource "aws_security_group_rule" "envoy_from_external_lb_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
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