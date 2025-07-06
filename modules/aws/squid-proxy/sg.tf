# Squid Internal Load Balancer Security Group
resource "aws_security_group" "squid_internal_lb_sg" {
  name                   = "${var.stack_name}-squid-internal-lb-sg"
  description            = "Security group for Squid internal ALB"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = {
    Name = "${var.stack_name}-squid-internal-lb-sg"
  }
}

# Allow EKS cluster to connect to Squid ALB
resource "aws_security_group_rule" "cluster_to_squid_lb" {
  type                     = "egress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  security_group_id        = var.eks_cluster_security_group_id
  source_security_group_id = aws_security_group.squid_internal_lb_sg.id
  description              = "Allow outbound traffic to Squid proxy"
}

resource "aws_security_group_rule" "squid_lb_from_cluster" {
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  security_group_id        = aws_security_group.squid_internal_lb_sg.id
  source_security_group_id = var.eks_cluster_security_group_id
  description              = "Allow traffic from EKS cluster security group"
}

# Squid ASG Security Group
resource "aws_security_group" "squid_asg_sg" {
  name                   = "${var.stack_name}-squid-asg-sg"
  description            = "Security group for Squid Auto Scaling Group instances"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = {
    Name = "${var.stack_name}-squid-asg-sg"
  }
}

# Squid Internal LB -> Squid ASG
resource "aws_security_group_rule" "squid_lb_to_asg" {
  type                     = "egress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  security_group_id        = aws_security_group.squid_internal_lb_sg.id
  source_security_group_id = aws_security_group.squid_asg_sg.id
  description              = "Allow traffic to Squid ASG instances"
}

resource "aws_security_group_rule" "squid_asg_from_lb" {
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  security_group_id        = aws_security_group.squid_asg_sg.id
  source_security_group_id = aws_security_group.squid_internal_lb_sg.id
  description              = "Allow traffic from Squid Internal LB"
}

# Squid ASG -> Internet
resource "aws_security_group_rule" "squid_asg_to_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.squid_asg_sg.id
  description       = "Allow HTTP to internet"
}

resource "aws_security_group_rule" "squid_asg_to_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.squid_asg_sg.id
  description       = "Allow HTTPS to internet"
}
