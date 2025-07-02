# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "${var.stack_name}-db-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-db-sg"
  })
}
