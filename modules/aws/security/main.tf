# Aws Current Region
data "aws_region" "current" {}

# Aws Caller Identity
data "aws_caller_identity" "current" {}

# ==========================================================
#                      Security Groups
# ==========================================================

# EKS Control Plane Security Group -
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.stack_name}-eks-cluster-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS cluster control plane"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-eks-cluster-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EKS Worker Nodes Security Group
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.stack_name}-eks-nodes-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS worker nodes"

  ingress {
    description = "Allow nodes to communicate with each other"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description     = "Allow pods to communicate with the cluster API Server"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name                                      = "${var.stack_name}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.stack_name}" = "owned"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.stack_name}-vpce-"
  vpc_id      = var.vpc_id
  description = "Security group for VPC Endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-vpce-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# External Load Balancer Security Group
resource "aws_security_group" "external_lb_sg" {
  name        = "hyperswitch-external-lb-sg"
  description = "Security group for external-facing load balancer"
  vpc_id      = var.vpc_id

  # Ingress rules - Only allow HTTP/HTTPS from CloudFront
  ingress {
    description = "HTTP from CloudFront"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = length(var.vpn_ips) > 0 ? var.vpn_ips : ["0.0.0.0/0"] # In production, use CloudFront prefix list
  }

  ingress {
    description = "HTTPS from CloudFront"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = length(var.vpn_ips) > 0 ? var.vpn_ips : ["0.0.0.0/0"] # In production, use CloudFront prefix list
  }

  # No egress rules here - will be added as specific rules

  tags = merge(var.common_tags, {
    Name = "hyperswitch-external-lb-sg"
  })
}

# Envoy Proxy Security Group
resource "aws_security_group" "envoy_sg" {
  name        = "hyperswitch-envoy-sg"
  description = "Security group for Envoy proxy instances"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "hyperswitch-envoy-sg"
  })
}

# Internal Load Balancer Security Group
resource "aws_security_group" "internal_lb_sg" {
  name        = "hyperswitch-internal-lb-sg"
  description = "Security group for internal load balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "hyperswitch-internal-lb-sg"
  })
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "${var.stack_name}-db-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-db-sg"
  })
}

# Security Group for ElastiCache
resource "aws_security_group" "elasticache_sg" {
  name        = "${var.stack_name}-elasticache-SG"
  description = "Security group for Hyperswitch ElastiCache"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-elasticache-SG"
  })
}


# ==========================================================
#                   Security Group Rules
# ==========================================================

# External LB -> Envoy (egress)
resource "aws_security_group_rule" "external_lb_to_envoy_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.envoy_sg.id
  security_group_id        = aws_security_group.external_lb_sg.id
  description              = "Allow traffic to Envoy proxy"
}

# External LB -> Envoy (ingress)
resource "aws_security_group_rule" "envoy_from_external_lb_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.external_lb_sg.id
  security_group_id        = aws_security_group.envoy_sg.id
  description              = "Allow traffic from External LB"
}

# Envoy -> Internal LB (egress)
resource "aws_security_group_rule" "envoy_to_internal_lb_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal_lb_sg.id
  security_group_id        = aws_security_group.envoy_sg.id
  description              = "Allow traffic to Internal LB"
}

# Envoy -> Internal LB (ingress)
resource "aws_security_group_rule" "internal_lb_from_envoy_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.envoy_sg.id
  security_group_id        = aws_security_group.internal_lb_sg.id
  description              = "Allow traffic from Envoy"
}

# Internal LB -> EKS (Istio Gateway - egress)
resource "aws_security_group_rule" "internal_lb_to_eks_egress" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.internal_lb_sg.id
  description              = "Allow traffic to EKS cluster"
}

# Internal LB -> EKS (Istio Gateway - health check - egress)
resource "aws_security_group_rule" "internal_lb_to_eks_health_egress" {
  type                     = "egress"
  from_port                = 15021
  to_port                  = 15021
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.internal_lb_sg.id
  description              = "Allow Istio health checks"
}

# Internal LB -> EKS (Istio Gateway - ingress)
resource "aws_security_group_rule" "eks_from_internal_lb_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal_lb_sg.id
  security_group_id        = aws_security_group.eks_cluster.id
  description              = "Allow traffic from Internal LB"
}

# ==========================================================
#                         IAM Roles
# ==========================================================

# EKS Cluster Service Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.stack_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# EKS Node Group Role
resource "aws_iam_role" "eks_node_group" {
  name = "${var.stack_name}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# KMS Lambda Role
resource "aws_iam_role" "kms_lambda" {
  name = "${var.stack_name}-kms-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


# ==========================================================
#                       IAM Policies
# ==========================================================

# EKS Cluster Policy
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Node Group Required Policies
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cloudwatch_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_ec2_readonly_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_node_group.name
}

# KMS Lambda Policy
resource "aws_iam_role_policy" "lambda_encryption_policy" {
  name = "${var.stack_name}-lambda-encryption-policy"
  role = aws_iam_role.kms_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:*"]
        Resource = ["*"]
      },
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = ["kms:*"]
        Resource = [aws_kms_key.hyperswitch_kms_key.arn]
      },
      {
        Sid      = "SSMAccess"
        Effect   = "Allow"
        Action   = ["ssm:*"]
        Resource = ["*"]
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.stack_name}-kms-encrypt",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.stack_name}-kms-encrypt:*"
        ]
      }
    ]
  })
}

# Custom CloudWatch Policy for Node Groups
resource "aws_iam_role_policy" "eks_cloudwatch_custom" {
  name = "${var.stack_name}-eks-cloudwatch-policy"
  role = aws_iam_role.eks_node_group.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport",
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents",
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "tag:GetResources",
        ]
        Resource = "*"
      }
    ]
  })
}


# ==========================================================
#                  KMS Keys and Aliases
# ==========================================================

# KMS Key for Hyperswitch
resource "aws_kms_key" "hyperswitch_kms_key" {
  description             = "KMS key for encrypting the objects in an S3 bucket"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = false # CDK: enableKeyRotation: false

  tags = var.common_tags
}

# Hyperswitch KMS Key Alias
resource "aws_kms_alias" "hyperswitch_kms_key_alias" {
  name          = "alias/${var.stack_name}-kms-key"
  target_key_id = aws_kms_key.hyperswitch_kms_key.key_id
}

# KMS Key for SSM
resource "aws_kms_key" "hyperswitch_ssm_kms_key" {
  description             = "KMS key for encrypting the objects in an S3 bucket"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true # CDK: enableKeyRotation: true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-ssm-kms-key"
  })
}

# Hyperswitch SSM KMS Key Alias
resource "aws_kms_alias" "hyperswitch_ssm_kms_key_alias" {
  name          = "alias/${var.stack_name}-ssm-kms-key"
  target_key_id = aws_kms_key.hyperswitch_ssm_kms_key.key_id
}

# ==========================================================
#                      Secrets Manager
# ==========================================================

resource "aws_secretsmanager_secret" "hyperswitch" {
  name        = "${var.stack_name}-kms-secrets"
  description = "KMS encryptable secrets for Hyperswitch"

  kms_key_id = aws_kms_key.hyperswitch_kms_key.key_id
}

resource "aws_secretsmanager_secret_version" "hyperswitch" {
  secret_id = aws_secretsmanager_secret.hyperswitch.id

  secret_string = jsonencode({
    db_password        = var.db_password
    jwt_secret         = var.jwt_secret
    master_key         = var.master_key
    admin_api_key      = var.admin_api_key
    kms_id             = aws_kms_key.hyperswitch_kms_key.key_id
    region             = data.aws_region.current.name
    locker_public_key  = var.locker_public_key
    tenant_private_key = var.tenant_private_key
  })
}

# RDS Database Secret
resource "aws_secretsmanager_secret" "db_master" {
  name        = "hypers-db-master-user-secret"
  description = "Database master user credentials"

  tags = merge(var.common_tags, {
    Name = "hypers-db-master-user-secret"

  })
}

resource "aws_secretsmanager_secret_version" "db_master" {
  secret_id = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({
    dbname   = var.db_name
    username = var.db_user
    password = var.db_password
  })
}
