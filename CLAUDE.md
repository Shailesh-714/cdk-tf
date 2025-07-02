# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform Infrastructure-as-Code project for deploying the Hyperswitch payment processing platform on AWS. The project uses a modular architecture with 228+ Terraform files organized across different cloud providers and environments.

## Architecture

### Directory Structure
```
/
├── environments/          # Environment-specific configurations
│   ├── aws/
│   │   ├── production/    # Production environment (current working dir)
│   │   └── free-tier/     # Free tier environment
│   ├── azure/             # Azure cloud configurations
│   └── gcp/               # Google Cloud configurations
├── modules/               # Reusable Terraform modules
│   ├── aws/               # AWS-specific modules
│   │   ├── networking/    # VPC, subnets, gateways
│   │   ├── security/      # Security groups, IAM, KMS, WAF
│   │   ├── eks/           # EKS cluster and node groups
│   │   ├── helm/          # Helm chart deployments
│   │   ├── rds/           # RDS database cluster
│   │   ├── elasticache/   # Redis cluster
│   │   ├── loadbalancers/ # ALB and CloudFront
│   │   ├── endpoints/     # VPC endpoints
│   │   ├── dockertoecr/   # Docker to ECR build pipeline
│   │   └── sdk/           # SDK distribution infrastructure
│   ├── azure/
│   └── gcp/
├── provider.tf           # Provider configurations (empty file)
├── backend.tf            # Terraform backend configuration
└── variables.tf          # Global variables
```

### Core Components

**Main Infrastructure Stack** (environments/aws/production/main.tf):
- VPC with public/private subnets across 2 AZs
- EKS cluster with managed node groups
- RDS Aurora PostgreSQL cluster
- ElastiCache Redis cluster
- Application Load Balancers with CloudFront
- VPC endpoints for AWS services
- Comprehensive security setup (IAM, security groups, KMS, WAF)

**Kubernetes Workloads** (modules/aws/helm/main.tf):
- AWS Load Balancer Controller
- EBS CSI Driver  
- Istio service mesh (base, istiod, ingress gateway)
- Hyperswitch application stack via Helm charts
- Traffic control with Istio configurations

### Key Technologies
- **Infrastructure**: Terraform, AWS
- **Container Orchestration**: EKS (Kubernetes)
- **Service Mesh**: Istio 1.25.0
- **Database**: RDS Aurora PostgreSQL
- **Cache**: ElastiCache Redis  
- **Load Balancing**: ALB + CloudFront
- **Package Management**: Helm charts
- **Security**: KMS encryption, IAM RBAC, WAF

## Development Commands

### Terraform Operations
```bash
# Initialize Terraform (run from environment directory)
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate
```

### Working Directory
The production environment is located at `/environments/aws/production/` and contains the main Terraform state and configuration files.

## Key Configuration Details

### Provider Versions
- AWS Provider: ~> 5.0
- Kubernetes Provider: 2.37.1  
- Helm Provider: 3.0.2
- Terraform: >= 0.12

### Important Variables
- `stack_name`: Used for resource naming (must be lowercase with hyphens only)
- `environment`: Environment identifier
- `vpc_cidr`: VPC CIDR block configuration
- `kubernetes_version`: EKS cluster version
- `sdk_version`: Currently "0.121.2"

### Security Notes
- KMS encryption is used for secrets management
- All sensitive values are encrypted and stored in AWS Secrets Manager
- Private ECR repositories are used for container images
- WAF protection is enabled for external load balancers
- VPN IP restrictions are configured for cluster access

### Module Dependencies
Most modules depend on outputs from the `vpc` and `security` modules. The Helm module has dependencies on EKS cluster completion and requires proper RBAC setup for service accounts.