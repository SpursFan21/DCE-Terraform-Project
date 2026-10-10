locals {
  services = var.service_names
}

# SNS topic for operational alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-critical-alerts"

  tags = {
    Name = "${var.project_name}-critical-alerts"
  }
}

# Register each ECS service as a scalable target
resource "aws_appautoscaling_target" "ecs" {
  for_each = local.services

  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_name}/${each.value}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Two scale-out policies
resource "aws_appautoscaling_policy" "scale_out" {
  for_each = local.services

  name               = "${var.project_name}-${each.key}-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[each.key].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

# Two scale-in policies
resource "aws_appautoscaling_policy" "scale_in" {
  for_each = local.services

  name               = "${var.project_name}-${each.key}-scale-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[each.key].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 180
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

# Two high CPU alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  for_each = local.services

  alarm_name          = "${var.project_name}-${each.key}-high-cpu"
  alarm_description   = "High ECS CPU utilisation for ${each.key}"
  comparison_operator = "GreaterThanOrEqualToThreshold"

  evaluation_periods = 2
  threshold          = 60
  metric_name        = "CPUUtilization"
  namespace          = "AWS/ECS"
  period             = 60
  statistic          = "Average"
  treat_missing_data = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value
  }

  alarm_actions = [
    aws_appautoscaling_policy.scale_out[each.key].arn,
    aws_sns_topic.alerts.arn
  ]
}

# Two low CPU alarms
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  for_each = local.services

  alarm_name          = "${var.project_name}-${each.key}-low-cpu"
  alarm_description   = "Low ECS CPU utilisation for ${each.key}"
  comparison_operator = "LessThanThreshold"

  evaluation_periods = 2
  threshold          = 20
  metric_name        = "CPUUtilization"
  namespace          = "AWS/ECS"
  period             = 60
  statistic          = "Average"
  treat_missing_data = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value
  }

  alarm_actions = [
    aws_appautoscaling_policy.scale_in[each.key].arn
  ]
}