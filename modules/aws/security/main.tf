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

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.stack_name}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  dynamic "ingress" {
    for_each = var.is_production ? [] : [1]
    content {
      description = "HTTP from anywhere"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = var.is_production ? [1] : []
    content {
      description = "HTTPS from VPN IPs"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = length(var.vpn_ips) > 0 ? var.vpn_ips : ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = var.is_production ? [1] : []
    content {
      description = "HTTP from VPN IPs"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = length(var.vpn_ips) > 0 ? var.vpn_ips : ["0.0.0.0/0"]
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-alb-sg"
    }
  )

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
}
