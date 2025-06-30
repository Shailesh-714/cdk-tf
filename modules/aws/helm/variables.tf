variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the VPC where the EKS cluster will be deployed"
  type        = string
}

variable "private_ecr_repository" {
  description = "ECR repository for private images"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "alb_controller_service_account_name" {
  description = "Name of the service account for the AWS Load Balancer Controller"
  type        = string
}

variable "ebs_csi_driver_service_account_name" {
  description = "Name of the service account for the EBS CSI Driver"
  type        = string
}
