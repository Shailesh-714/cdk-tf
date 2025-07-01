output "external_alb_distribution_domain_name" {
  value       = aws_cloudfront_distribution.external_alb_distribution.domain_name
  description = "The domain name of the external ALB CloudFront distribution"
}
