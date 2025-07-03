# Internal Load Balancer Security Group
resource "aws_security_group" "internal_alb_sg" {
  name        = "${var.stack_name}-internal-alb-sg"
  description = "Security group for internal load balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-internal-alb-sg"
  })
}

# Internal LB -> EKS (Istio Gateway - egress)
resource "aws_security_group_rule" "internal_alb_to_eks_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.eks_cluster_security_group_id
  security_group_id        = aws_security_group.internal_alb_sg.id
  description              = "Allow traffic to EKS cluster"
}

# Internal LB -> EKS (Istio Gateway - health check - egress)
resource "aws_security_group_rule" "internal_alb_to_eks_health_egress" {
  type                     = "egress"
  from_port                = 15021
  to_port                  = 15021
  protocol                 = "tcp"
  source_security_group_id = var.eks_cluster_security_group_id
  security_group_id        = aws_security_group.internal_alb_sg.id
  description              = "Allow Istio health checks"
}

resource "aws_security_group_rule" "eks_from_internal_alb_health_ingress" {
  type                     = "ingress"
  from_port                = 15021
  to_port                  = 15021
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal_alb_sg.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow Istio health checks from Internal LB"
}

# Internal LB -> EKS (Istio Gateway - ingress)
resource "aws_security_group_rule" "eks_from_internal_alb_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal_alb_sg.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow traffic from Internal LB"
}

resource "aws_security_group" "grafana_ingress_lb_sg" {
  name        = "${var.stack_name}-grafana-ingress-lb"
  description = "Security group for Grafana ingress load balancer"
  vpc_id      = var.vpc_id

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.stack_name}-grafana-ingress-lb"
  }
}

resource "aws_security_group_rule" "grafana_ingress_lb_vpn_https" {
  for_each = { for ip in var.vpn_ips : ip => ip if ip != "0.0.0.0/0" }

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  description       = "Allow port 443 from VPN IP ${each.value}"
}

resource "aws_security_group_rule" "grafana_ingress_lb_vpn_http" {
  for_each = { for ip in var.vpn_ips : ip => ip if ip != "0.0.0.0/0" }

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  description       = "Allow port 80 from VPN IP ${each.value}"
}

resource "aws_security_group_rule" "eks_from_grafana_lb_3000" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow port 3000 from Grafana LB SG"
}

resource "aws_security_group_rule" "eks_from_grafana_lb_80" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow port 80 from Grafana LB SG"
}
