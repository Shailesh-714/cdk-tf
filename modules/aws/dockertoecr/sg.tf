# Security Group for Lambda function
resource "aws_security_group" "lambda" {
  name_prefix = "${var.stack_name}-docker-to-ecr-lambda-"
  vpc_id      = var.vpc_id
  description = "Security group for CodeBuild trigger Lambda function"

  # Egress rules - Lambda needs to communicate with CodeBuild and other AWS services
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS API calls"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-docker-to-ecr-lambda-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
