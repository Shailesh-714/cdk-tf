output "envoy_asg_security_group_id" {
  description = "Security Group ID for Envoy ASG instances"
  value       = aws_security_group.envoy_sg.id
}

output "squid_alb_dns" {
  description = "DNS name of the Squid Network Load Balancer"
  value       = aws_lb.squid_nlb.dns_name
}
