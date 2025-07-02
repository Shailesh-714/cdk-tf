output "internal_lb_security_group_id" {
  description = "ID of the Internal Load Balancer Security Group"
  value       = aws_security_group.internal_lb_sg.id
}
