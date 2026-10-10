output "repository_urls" {
  description = "ECR repository URLs for the two services"

  value = {
    for name, repo in aws_ecr_repository.microservices :
    name => repo.repository_url
  }
}

output "repository_names" {
  description = "Names of the ECR repositories"

  value = {
    for name, repo in aws_ecr_repository.microservices :
    name => repo.name
  }
}

output "repository_arns" {
  description = "ECR repository ARNs"

  value = {
    for name, repo in aws_ecr_repository.microservices :
    name => repo.arn
  }
}