output "sns_topic_arn" {
  description = "Critical alert SNS topic ARN"
  value       = aws_sns_topic.alerts.arn
}

output "scaling_target_ids" {
  description = "ECS autoscaling targets"
  value = {
    for name, target in aws_appautoscaling_target.ecs :
    name => target.resource_id
  }
}

output "high_cpu_alarm_names" {
  description = "High CPU alarm names"
  value = {
    for name, alarm in aws_cloudwatch_metric_alarm.high_cpu :
    name => alarm.alarm_name
  }
}

output "low_cpu_alarm_names" {
  description = "Low CPU alarm names"
  value = {
    for name, alarm in aws_cloudwatch_metric_alarm.low_cpu :
    name => alarm.alarm_name
  }
}