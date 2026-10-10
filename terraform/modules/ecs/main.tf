locals {
  services = toset(["service-a", "service-b"])
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# CloudWatch container logs
resource "aws_cloudwatch_log_group" "services" {
  for_each = local.services

  name              = "/ecs/${var.project_name}/${each.key}"
  retention_in_days = 7
}

# IAM trust policy for Fargate task execution
data "aws_iam_policy_document" "ecs_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ECS task execution role
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_execution_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Fargate task definitions
resource "aws_ecs_task_definition" "services" {
  for_each = local.services

  family                   = "${var.project_name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${var.repository_urls[each.key]}:v1"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.services[each.key].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${each.key}-task"
  }
}

# ECS Fargate services
resource "aws_ecs_service" "services" {
  for_each = local.services

  name            = "${var.project_name}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn

  desired_count = var.desired_count
  launch_type   = "FARGATE"

  network_configuration {
    subnets = var.public_subnet_ids

    security_groups = [
      var.ecs_security_group_ids[each.key]
    ]

    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.target_group_arns["${each.key}-blue"]
    container_name   = each.key
    container_port   = var.container_port
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
      load_balancer
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution
  ]

  tags = {
    Name = "${var.project_name}-${each.key}-ecs-service"
  }
}