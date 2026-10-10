locals {
  services = toset(["service-a", "service-b"])

  target_groups = {
    for pair in setproduct(
      ["service-a", "service-b"],
      ["blue", "green"]
    ) :
    "${pair[0]}-${pair[1]}" => {
      service = pair[0]
      color   = pair[1]
    }
  }
}

# Two public-facing Application Load Balancers
resource "aws_lb" "microservices" {
  for_each = local.services

  name               = "${var.project_name}-${each.key}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    var.alb_security_group_ids[each.key]
  ]

  subnets = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${each.key}-alb"
  }
}

# Blue and Green target groups for each service
resource "aws_lb_target_group" "microservices" {
  for_each = local.target_groups

  name        = "${var.project_name}-${each.key}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-${each.key}-tg"
  }
}

# HTTP production listeners
resource "aws_lb_listener" "http" {
  for_each = local.services

  load_balancer_arn = aws_lb.microservices[each.key].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    target_group_arn = aws_lb_target_group.microservices[
      "${each.key}-blue"
    ].arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}