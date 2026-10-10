output "ecr_repository_urls" {
  description = "ECR repositories for microservice images"
  value       = module.ecr.repository_urls
}

output "alb_dns_names" {
  description = "Public endpoints for both microservices"
  value       = module.alb.alb_dns_names
}

output "alb_target_group_arns" {
  description = "Blue and Green target groups"
  value       = module.alb.target_group_arns
}

output "ecs_cluster_name" {
  description = "ECS Fargate cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_names" {
  description = "ECS microservice names"
  value       = module.ecs.service_names
}

output "sns_alert_topic_arn" {
  description = "SNS topic for critical alerts"
  value       = module.monitoring.sns_topic_arn
}

output "s3_artifacts_bucket" {
  description = "S3 bucket for CodePipeline artifacts"
  value       = module.data.artifacts_bucket_name
}

output "s3_assets_bucket" {
  description = "S3 bucket for application assets"
  value       = module.data.assets_bucket_name
}

output "dynamodb_table_name" {
  description = "DynamoDB transaction table"
  value       = module.data.dynamodb_table_name
}

output "codedeploy_app_names" {
  description = "CodeDeploy applications"
  value       = module.cicd.codedeploy_app_names
}

output "codedeploy_group_names" {
  description = "Blue/Green deployment groups"
  value       = module.cicd.deployment_group_names
}

output "codebuild_project_names" {
  description = "AWS CodeBuild projects"
  value       = module.cicd.codebuild_project_names
}

output "codepipeline_name" {
  description = "Automated CI/CD pipeline name"
  value       = module.cicd.pipeline_name
}