# ==========================================================
#              EKS Cluster Security Group Rules
# ==========================================================

# resource "aws_security_group_rule" "eks_block_all_egress" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = []
#   description       = "Block all egress traffic from EKS cluster nodes and pods"
#   security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
# }

resource "aws_security_group_rule" "eks_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS for EKS API, ECR, S3"
  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "eks_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow DNS UDP"
  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "eks_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow DNS TCP"
  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# ==========================================================
#              RDS and Elasticache Connections
# ==========================================================

resource "aws_security_group_rule" "rds_ingress_from_eks" {
  type                     = "ingress"
  from_port                = 5432 # PostgreSQL port
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  security_group_id        = var.rds_security_group_id
  description              = "Allow EKS cluster nodes and pods to connect to RDS PostgreSQL"
}

resource "aws_security_group_rule" "elasticache_ingress_from_eks" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  security_group_id        = var.elasticache_security_group_id
  description              = "Allow Redis access from EKS cluster"
}
