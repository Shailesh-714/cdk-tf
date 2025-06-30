terraform {
  required_version = ">= 0.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.37.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
  }
}

# Provider configurations
provider "aws" {
  region = var.aws_region
}

# Data sources for existing resources
data "aws_availability_zones" "available" {
  state = "available"
}


data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Stack       = "Hyperswitch"
    StackName   = var.stack_name # Dynamic stack name per environment
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Determine if the environment is production
  is_production = true

  # VPC CIDR configuration
  vpc_cidr = var.vpc_cidr

  # Availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Private ECR repository for EKS
  private_ecr_repository = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

# VPC configuration
module "vpc" {
  source = "../../../modules/aws/networking"

  vpc_cidr             = local.vpc_cidr
  availability_zones   = slice(local.azs, 0, 2)
  stack_name           = var.stack_name
  common_tags          = local.common_tags
  enable_nat_gateway   = true
  single_nat_gateway   = !local.is_production
  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "security" {
  source = "../../../modules/aws/security"

  stack_name    = var.stack_name
  common_tags   = local.common_tags
  is_production = local.is_production
  vpc_id        = module.vpc.vpc_id
  vpc_cidr      = local.vpc_cidr
  vpn_ips       = var.vpn_ips

  db_password        = var.db_password
  jwt_secret         = var.jwt_secret
  master_key         = var.master_key
  admin_api_key      = var.admin_api_key
  locker_public_key  = var.locker_public_key
  tenant_private_key = var.tenant_private_key
}

module "endpoints" {
  source = "../../../modules/aws/endpoints"

  stack_name                       = var.stack_name
  common_tags                      = local.common_tags
  vpc_id                           = module.vpc.vpc_id
  isolated_route_table_id          = module.vpc.isolated_route_table_id
  private_with_nat_route_table_ids = module.vpc.private_with_nat_route_table_ids
  subnet_ids                       = module.vpc.subnet_ids
  vpc_endpoints_security_group_id  = module.security.vpc_endpoints_security_group_id
}

module "loadbalancers" {
  source = "../../../modules/aws/loadbalancers"

  stack_name                    = var.stack_name
  common_tags                   = local.common_tags
  vpc_id                        = module.vpc.vpc_id
  subnet_ids                    = module.vpc.subnet_ids
  external_lb_security_group_id = module.security.external_lb_security_group_id
  waf_web_acl_arn               = module.security.waf_web_acl_arn
  # vpc_endpoints_security_group_id = module.security.vpc_endpoints_security_group_id
}

module "eks" {
  source = "../../../modules/aws/eks"

  stack_name                    = var.stack_name
  common_tags                   = local.common_tags
  vpc_id                        = module.vpc.vpc_id
  vpc_cidr                      = local.vpc_cidr
  subnet_ids                    = module.vpc.subnet_ids
  private_subnet_ids            = module.vpc.eks_worker_nodes_subnet_ids
  control_plane_subnet_ids      = module.vpc.eks_control_plane_zone_subnet_ids
  kubernetes_version            = var.kubernetes_version
  vpn_ips                       = var.vpn_ips
  eks_cluster_security_group_id = module.security.eks_cluster_security_group_id
  eks_cluster_role_arn          = module.security.eks_cluster_role_arn
  eks_node_group_role_arn       = module.security.eks_node_group_role_arn
  kms_key_arn                   = module.security.hyperswitch_kms_key_arn
  log_retention_days            = var.log_retention_days
}

module "helm" {
  source = "../../../modules/aws/helm"

  stack_name                          = var.stack_name
  common_tags                         = local.common_tags
  vpc_id                              = module.vpc.vpc_id
  private_ecr_repository              = local.private_ecr_repository
  eks_cluster_name                    = module.eks.eks_cluster_name
  alb_controller_service_account_name = module.eks.alb_controller_service_account_name
  ebs_csi_driver_service_account_name = module.eks.ebs_csi_driver_service_account_name

}
