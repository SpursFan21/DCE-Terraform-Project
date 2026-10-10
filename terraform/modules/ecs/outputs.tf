output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "service_names" {
  description = "ECS service names"

  value = {
    for name, service in aws_ecs_service.services :
    name => service.name
  }
}

output "task_definition_arns" {
  description = "Fargate task definition ARNs"

  value = {
    for name, task in aws_ecs_task_definition.services :
    name => task.arn
  }
}