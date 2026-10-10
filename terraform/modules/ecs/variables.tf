variable "project_name" {
  description = "Project resource naming prefix"
  type        = string
}

variable "aws_region" {
  description = "AWS deployment region"
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets for ECS Fargate tasks"
  type        = list(string)
}

variable "ecs_security_group_ids" {
  description = "Security groups for the two services"
  type        = map(string)
}

variable "repository_urls" {
  description = "ECR image repository URLs"
  type        = map(string)
}

variable "target_group_arns" {
  description = "Blue and Green ALB target group ARNs"
  type        = map(string)
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  description = "Initial task count per service"
  type        = number
  default     = 1
}