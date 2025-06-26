variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
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

variable "isolated_route_table_id" {
  description = "Route table ID for isolated subnets"
  type        = string
}

variable "private_with_nat_route_table_ids" {
  description = "List of route table IDs for private subnets with NAT"
  type        = list(string)
  default     = []
}

variable "incoming_web_envoy_zone_subnet_ids" {
  description = "List of subnet IDs for incoming web envoy zone"
  type        = list(string)
}

variable "vpc_endpoints_security_group_id" {
  type        = string
  description = "Security group ID to attach to VPC interface endpoints"
}
