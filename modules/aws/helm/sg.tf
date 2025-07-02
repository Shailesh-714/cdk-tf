# Internal Load Balancer Security Group
resource "aws_security_group" "internal_lb_sg" {
  name        = "${var.stack_name}-internal-lb-sg"
  description = "Security group for internal load balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-internal-lb-sg"
  })
}

# Internal LB -> EKS (Istio Gateway - egress)
resource "aws_security_group_rule" "internal_lb_to_eks_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.eks_cluster_security_group_id
  security_group_id        = aws_security_group.internal_lb_sg.id
  description              = "Allow traffic to EKS cluster"
}

# Internal LB -> EKS (Istio Gateway - health check - egress)
resource "aws_security_group_rule" "internal_lb_to_eks_health_egress" {
  type                     = "egress"
  from_port                = 15021
  to_port                  = 15021
  protocol                 = "tcp"
  source_security_group_id = var.eks_cluster_security_group_id
  security_group_id        = aws_security_group.internal_lb_sg.id
  description              = "Allow Istio health checks"
}

# Internal LB -> EKS (Istio Gateway - ingress)
resource "aws_security_group_rule" "eks_from_internal_lb_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal_lb_sg.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow traffic from Internal LB"
}
