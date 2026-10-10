# IAM trust policy for AWS CodeBuild
data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.project_name}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
}

# CloudWatch logs for each build project
resource "aws_cloudwatch_log_group" "codebuild" {
  for_each = local.services

  name              = "/aws/codebuild/${var.project_name}-${each.key}-build"
  retention_in_days = 7
}

# Permissions required by the build processes
data "aws_iam_policy_document" "codebuild" {
  statement {
    sid       = "ECRAuthentication"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushContainerImages"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = values(var.repository_arns)
  }

  statement {
    sid    = "CloudWatchBuildLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      for group in aws_cloudwatch_log_group.codebuild :
      "${group.arn}:*"
    ]
  }

  statement {
    sid    = "PipelineArtifacts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${var.artifacts_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "PipelineArtifactBucketLocation"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]

    resources = [var.artifacts_bucket_arn]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.project_name}-codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

# Two independent CodeBuild projects
resource "aws_codebuild_project" "services" {
  for_each = local.services

  name          = "${var.project_name}-${each.key}-build"
  description   = "Docker build and ECR publish for ${each.key}"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "SERVICE_NAME"
      value = each.key
    }

    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = var.repository_urls[each.key]
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.codebuild[each.key].name
    }
  }

  depends_on = [
    aws_iam_role_policy.codebuild
  ]

  tags = {
    Name = "${var.project_name}-${each.key}-build"
  }
}