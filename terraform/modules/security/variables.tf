variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC where security groups will be created"
  type        = string
}

variable "container_port" {
  description = "Port used by the microservice containers"
  type        = number
  default     = 8080
}