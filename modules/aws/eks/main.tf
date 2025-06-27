# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.stack_name}-cluster"
  role_arn = var.eks_cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.control_plane_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = length(var.vpn_ips) > 0 ? var.vpn_ips : ["0.0.0.0/0"]
    security_group_ids      = [var.eks_cluster_security_group_id]
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-cluster"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.eks
  ]
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.stack_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}
