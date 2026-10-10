variable "project_name" {
  description = "Project resource naming prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC for the load balancers"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets across two AZs"
  type        = list(string)
}

variable "alb_security_group_ids" {
  description = "Security group IDs for each ALB"
  type        = map(string)
}

variable "container_port" {
  description = "Port used by ECS containers"
  type        = number
  default     = 8080
}