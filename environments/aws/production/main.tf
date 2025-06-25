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

  # VPC CIDR configuration
  vpc_cidr = var.vpc_cidr

  # Availability zones
  azs = data.aws_availability_zones.available.names
}

# VPC configuration
