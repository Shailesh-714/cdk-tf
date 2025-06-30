output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name

}

output "hyperswitch_service_account_role_arn" {
  description = "The ARN of the Hyperswitch service account role"
  value       = aws_iam_role.hyperswitch_service_account.arn
}

output "alb_controller_service_account_name" {
  description = "The name of the service account for the AWS Load Balancer Controller"
  value       = kubernetes_service_account.alb_controller.metadata[0].name
}

output "ebs_csi_driver_service_account_name" {
  description = "The name of the service account for the EBS CSI Driver"
  value       = kubernetes_service_account.ebs_csi_controller_sa.metadata[0].name
}
