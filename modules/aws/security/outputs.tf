output "envoy_security_group_id" {
  description = "ID of the Envoy Security Group"
  value       = aws_security_group.envoy_sg.id
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

# Output for KMS secrets
output "kms_secrets" {
  value = merge(
    { for k, v in data.aws_ssm_parameter.all : k => v.value }
  )
  sensitive = true
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.hyperswitch_waf.arn

}
