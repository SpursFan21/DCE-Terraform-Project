locals {
  services = toset(["service-a", "service-b"])
}

# IAM trust policy for CodeDeploy
data "aws_iam_policy_document" "codedeploy_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

# IAM service role
resource "aws_iam_role" "codedeploy" {
  name = "${var.project_name}-codedeploy-role"

  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume_role.json
}

# AWS managed ECS CodeDeploy policy
resource "aws_iam_role_policy_attachment" "codedeploy" {
  role = aws_iam_role.codedeploy.name

  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# CodeDeploy applications
resource "aws_codedeploy_app" "services" {
  for_each = local.services

  compute_platform = "ECS"
  name             = "${var.project_name}-${each.key}-deployment"
}

# Blue/Green deployment groups
resource "aws_codedeploy_deployment_group" "services" {
  for_each = local.services

  app_name = aws_codedeploy_app.services[each.key].name

  deployment_group_name = "${var.project_name}-${each.key}-bluegreen"

  service_role_arn = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  auto_rollback_configuration {
    enabled = true

    events = [
      "DEPLOYMENT_FAILURE",
      "DEPLOYMENT_STOP_ON_ALARM"
    ]
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  ecs_service {
    cluster_name = var.cluster_name
    service_name = var.service_names[each.key]
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          var.listener_arns[each.key]
        ]
      }

      target_group {
        name = split(
          "/",
          var.target_group_arns["${each.key}-blue"]
        )[1]
      }

      target_group {
        name = split(
          "/",
          var.target_group_arns["${each.key}-green"]
        )[1]
      }
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.codedeploy
  ]
}