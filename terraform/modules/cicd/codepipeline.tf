
# IAM trust policy for CodePipeline
data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.project_name}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json
}

# Permissions required for pipeline execution
data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid    = "GitHubConnection"
    effect = "Allow"

    actions = [
      "codeconnections:UseConnection",
      "codestar-connections:UseConnection"
    ]

    resources = [var.github_connection_arn]
  }

  statement {
    sid    = "ArtifactBucket"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket"
    ]

    resources = [var.artifacts_bucket_arn]
  }

  statement {
    sid    = "PipelineArtifacts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]

    resources = ["${var.artifacts_bucket_arn}/*"]
  }

  # Allow CodePipeline to retrieve container image metadata
  # from the two Amazon ECR repositories.
  statement {
    sid    = "ReadECRImages"
    effect = "Allow"

    actions = [
      "ecr:DescribeImages"
    ]

    resources = [
      "arn:aws:ecr:ap-southeast-2:488510448462:repository/dce04-service-a",
      "arn:aws:ecr:ap-southeast-2:488510448462:repository/dce04-service-b"
    ]
  }

  statement {
    sid    = "CodeDeployApplications"
    effect = "Allow"

    actions = [
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:RegisterApplicationRevision"
    ]

    resources = [
      for app in aws_codedeploy_app.services :
      app.arn
    ]
  }

  statement {
    sid    = "CodeDeployDeployments"
    effect = "Allow"

    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentGroup"
    ]

    resources = [
      for group in aws_codedeploy_deployment_group.services :
      group.arn
    ]
  }

  statement {
    sid       = "DeploymentConfiguration"
    effect    = "Allow"
    actions   = ["codedeploy:GetDeploymentConfig"]
    resources = ["*"]
  }

  statement {
    sid       = "RegisterECSTaskDefinition"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "DescribeECSTaskDefinition"
    effect    = "Allow"
    actions   = ["ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "PassECSTaskExecutionRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [var.ecs_execution_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${var.project_name}-codepipeline-policy"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}

# CodePipeline:
# GitHub + two ECR image sources -> parallel Blue/Green deployments
resource "aws_codepipeline" "main" {
  name          = "${var.project_name}-microservices-pipeline"
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V1"

  artifact_store {
    location = var.artifacts_bucket_name
    type     = "S3"
  }

  # SOURCE STAGE
  stage {
    name = "Source"

    # GitHub provides the ECS task definition and AppSpec templates.
    action {
      name             = "GitHubSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      run_order        = 1

      configuration = {
        ConnectionArn        = var.github_connection_arn
        FullRepositoryId     = var.github_repository
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = "false"
      }
    }

    # ECR provides the imageDetail.json artifact for each service.
    dynamic "action" {
      for_each = local.services

      content {
        name      = "ECR-${action.value}"
        category  = "Source"
        owner     = "AWS"
        provider  = "ECR"
        version   = "1"
        run_order = 1

        output_artifacts = [
          action.value == "service-a" ? "ImageAArtifact" : "ImageBArtifact"
        ]

        configuration = {
          RepositoryName = "${var.project_name}-${action.value}"
          ImageTag       = "v2"
        }
      }
    }
  }

  # DEPLOY STAGE
  # Two parallel AWS CodeDeploy Blue/Green deployments.
  stage {
    name = "Deploy"

    dynamic "action" {
      for_each = local.services

      content {
        name      = "Deploy-${action.value}"
        category  = "Deploy"
        owner     = "AWS"
        provider  = "CodeDeployToECS"
        version   = "1"
        run_order = 1

        input_artifacts = [
          "SourceArtifact",
          action.value == "service-a" ? "ImageAArtifact" : "ImageBArtifact"
        ]

        configuration = {
          ApplicationName = aws_codedeploy_app.services[action.value].name

          DeploymentGroupName = aws_codedeploy_deployment_group.services[action.value].deployment_group_name

          TaskDefinitionTemplateArtifact = "SourceArtifact"
          TaskDefinitionTemplatePath     = "deployment/${action.value}/taskdef.json"

          AppSpecTemplateArtifact = "SourceArtifact"
          AppSpecTemplatePath     = "deployment/${action.value}/appspec.yaml"

          Image1ArtifactName = (
            action.value == "service-a"
            ? "ImageAArtifact"
            : "ImageBArtifact"
          )

          Image1ContainerName = "IMAGE1_NAME"
        }
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.codepipeline
  ]

  tags = {
    Name = "${var.project_name}-microservices-pipeline"
  }
}
