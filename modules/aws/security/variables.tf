variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "is_production" {
  description = "Boolean indicating if the environment is production"
  type        = bool
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "vpn_ips" {
  description = "List of VPN IPs for security group rules"
  type        = list(string)
  default     = []
}
