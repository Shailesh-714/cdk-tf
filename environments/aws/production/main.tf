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
  #   enable_vpc_endpoints = true
}
