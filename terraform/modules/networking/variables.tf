variable "project_name" {
  description = "Project resource naming prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR range for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the public subnets"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}