variable "project_name" {
  description = "Project naming prefix"
  type        = string
}

variable "cluster_name" {
  description = "Existing ECS cluster"
  type        = string
}

variable "service_names" {
  description = "ECS service names"
  type        = map(string)
}

variable "target_group_arns" {
  description = "Blue and Green ALB target group ARNs"
  type        = map(string)
}

variable "listener_arns" {
  description = "Production ALB listener ARNs"
  type        = map(string)
}

variable "aws_region" {
  description = "AWS region used by CodeBuild"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account containing the ECR repositories"
  type        = string
}

variable "repository_urls" {
  description = "ECR repository URLs for each microservice"
  type        = map(string)
}

variable "repository_arns" {
  description = "ECR repository ARNs for IAM permissions"
  type        = map(string)
}

variable "artifacts_bucket_arn" {
  description = "Existing CodePipeline artifacts bucket ARN"
  type        = string
}

variable "github_connection_arn" {
  description = "Existing GitHub CodeConnections ARN"
  type        = string
}

variable "github_repository" {
  description = "GitHub owner/repository"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch used by CodePipeline"
  type        = string
  default     = "main"
}

variable "artifacts_bucket_name" {
  description = "Existing S3 pipeline artifacts bucket"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "IAM execution role used by ECS task definitions"
  type        = string
}