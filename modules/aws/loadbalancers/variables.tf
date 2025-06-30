variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "subnet_ids" {
  description = "List of subnet IDs for the load balancers"
  type        = map(list(string))
}

variable "external_lb_security_group_id" {
  description = "Security Group ID for the external load balancer"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL to associate with the load balancers"
  type        = string
}
