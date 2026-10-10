# S3 bucket for CI/CD pipeline artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-artifacts-${var.bucket_suffix}"
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-artifacts"
    Purpose = "CodePipeline-Artifacts"
  }
}

# S3 bucket for application assets and DR backup
resource "aws_s3_bucket" "assets" {
  bucket        = "${var.project_name}-assets-${var.bucket_suffix}"
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-assets"
    Purpose = "Application-Assets"
  }
}

locals {
  bucket_ids = {
    artifacts = aws_s3_bucket.artifacts.id
    assets    = aws_s3_bucket.assets.id
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = local.bucket_ids

  bucket = each.value

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "buckets" {
  for_each = local.bucket_ids

  bucket = each.value

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = local.bucket_ids

  bucket = each.value

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB transaction table
resource "aws_dynamodb_table" "transactions" {
  name         = "${var.project_name}-transactions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "transaction_id"

  attribute {
    name = "transaction_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name    = "${var.project_name}-transactions"
    Purpose = "Application-Data"
  }
}