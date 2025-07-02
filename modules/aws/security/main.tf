# Aws Current Region
data "aws_region" "current" {}

# Aws Caller Identity
data "aws_caller_identity" "current" {}


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

  # only for development purposes
  recovery_window_in_days        = 0
  force_overwrite_replica_secret = true

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
  name        = "${var.stack_name}-db-master-user-secret"
  description = "Database master user credentials"

  # only for development purposes
  recovery_window_in_days        = 0
  force_overwrite_replica_secret = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-db-master-user-secret"

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
