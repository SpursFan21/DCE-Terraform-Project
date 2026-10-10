resource "aws_security_group" "alb" {
  for_each = toset(["service-a", "service-b"])

  name_prefix = "${var.project_name}-${each.key}-alb-"
  description = "Public ALB security group for ${each.key}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${each.key}-alb-sg"
  }
}

resource "aws_security_group" "ecs" {
  for_each = toset(["service-a", "service-b"])

  name_prefix = "${var.project_name}-${each.key}-ecs-"
  description = "ECS task security group for ${each.key}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${each.key}-ecs-sg"
  }
}

# Public HTTP access to ALBs
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = aws_security_group.alb

  security_group_id = each.value.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"

  description = "Allow public HTTP traffic"
}

# ECS tasks only accept traffic from their matching ALB
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  for_each = aws_security_group.ecs

  security_group_id            = each.value.id
  referenced_security_group_id = aws_security_group.alb[each.key].id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"

  description = "Allow container traffic only from matching ALB"
}

# ALB outbound traffic to matching ECS tasks
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  for_each = aws_security_group.alb

  security_group_id            = each.value.id
  referenced_security_group_id = aws_security_group.ecs[each.key].id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"

  description = "Allow forwarding to matching ECS tasks"
}

# ECS outbound traffic for image downloads, AWS APIs and logs
resource "aws_vpc_security_group_egress_rule" "ecs_outbound" {
  for_each = aws_security_group.ecs

  security_group_id = each.value.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  description = "Allow outbound connections from ECS tasks"
}