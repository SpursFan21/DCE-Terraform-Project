output "codedeploy_app_names" {
  description = "CodeDeploy application names"

  value = {
    for name, app in aws_codedeploy_app.services :
    name => app.name
  }
}

output "deployment_group_names" {
  description = "Blue/Green deployment group names"

  value = {
    for name, group in aws_codedeploy_deployment_group.services :
    name => group.deployment_group_name
  }
}

output "codebuild_project_names" {
  description = "CodeBuild projects for both microservices"

  value = {
    for name, project in aws_codebuild_project.services :
    name => project.name
  }
}