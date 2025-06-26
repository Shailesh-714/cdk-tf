output "eks_cluster_security_group_id" {
  description = "ID of the EKS Cluster Security Group"
  value       = aws_security_group.eks_cluster.id
}

output "eks_nodes_security_group_id" {
  description = "ID of the EKS Worker Nodes Security Group"
  value       = aws_security_group.eks_nodes.id
}

output "alb_security_group_id" {
  description = "ID of the ALB Security Group"
  value       = aws_security_group.alb.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC Endpoints Security Group"
  value       = aws_security_group.vpc_endpoints.id
}
