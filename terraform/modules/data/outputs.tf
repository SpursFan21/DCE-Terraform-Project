output "artifacts_bucket_name" {
  description = "CodePipeline artifacts bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "CodePipeline artifacts bucket ARN"
  value       = aws_s3_bucket.artifacts.arn
}

output "assets_bucket_name" {
  description = "Application assets bucket"
  value       = aws_s3_bucket.assets.id
}

output "assets_bucket_arn" {
  description = "Application assets bucket ARN"
  value       = aws_s3_bucket.assets.arn
}

output "dynamodb_table_name" {
  description = "Application transaction table"
  value       = aws_dynamodb_table.transactions.name
}

output "dynamodb_table_arn" {
  description = "Application transaction table ARN"
  value       = aws_dynamodb_table.transactions.arn
}