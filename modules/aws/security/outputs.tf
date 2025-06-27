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

output "hyperswitch_kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.hyperswitch_kms_key.id
}

output "hyperswitch_kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.hyperswitch_kms_key.arn
}

output "hyperswitch_kms_key_alias" {
  description = "Alias of the KMS key"
  value       = aws_kms_alias.hyperswitch_kms_key_alias.name
}

output "hyperswitch_ssm_kms_key_id" {
  description = "ID of the SSM KMS key"
  value       = aws_kms_key.hyperswitch_ssm_kms_key.id
}

output "hyperswitch_ssm_kms_key_arn" {
  description = "ARN of the SSM KMS key"
  value       = aws_kms_key.hyperswitch_ssm_kms_key.arn
}

output "hyperswitch_ssm_kms_key_alias" {
  description = "Alias of the SSM KMS key"
  value       = aws_kms_alias.hyperswitch_ssm_kms_key_alias.name
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS Cluster IAM Role"
  value       = aws_iam_role.eks_cluster.arn
}
output "eks_node_group_role_arn" {
  description = "ARN of the EKS Node Group IAM Role"
  value       = aws_iam_role.eks_node_group.arn
}
