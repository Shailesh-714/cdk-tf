# ==========================================================
#                  OpenID Connect Provider
# ==========================================================

# OIDC Provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.common_tags
}

# ==========================================================
#            IAM Roles for Service Accounts (IRSA)
# ==========================================================

# Hyperswitch Router Service Account Role
resource "aws_iam_role" "hyperswitch_service_account" {
  name = "${var.stack_name}-hyperswitch-service-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:hyperswitch:hyperswitch-router-role"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# KMS and other policies for Hyperswitch
resource "aws_iam_policy" "hyperswitch_service_account_policy" {
  name        = "${var.stack_name}-hyperswitch-service-account-policy"
  description = "Policy for Hyperswitch KMS, lb, ssm, secrets manager service access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = ["kms:*"]
        Resource = [var.kms_key_arn != null ? var.kms_key_arn : "*"]
      },
      {
        Sid    = "LoadBalancerAccess"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers"
        ]
        Resource = ["*"]
      },
      {
        Sid      = "SSMAccess"
        Effect   = "Allow"
        Action   = ["ssm:*"]
        Resource = ["*"]
      },
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:*"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "hyperswitch_service_account_policy_attachment" {
  policy_arn = aws_iam_policy.hyperswitch_service_account_policy.arn
  role       = aws_iam_role.hyperswitch_service_account.name
}

# Module for AWS Load Balancer Controller IRSA
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.stack_name}-alb-controller-role"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.eks.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller-sa"]
    }
  }
}

# Service account for AWS Load Balancer Controller
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller-sa"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.aws_load_balancer_controller_irsa.iam_role_arn
    }
  }
}


resource "kubernetes_service_account" "ebs_csi_controller_sa" {
  metadata {
    name      = "ebs-csi-controller-sa-${data.aws_region.current.name}"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.eks_node_group_role_arn
    }
  }
  depends_on = [aws_eks_cluster.main]
}
