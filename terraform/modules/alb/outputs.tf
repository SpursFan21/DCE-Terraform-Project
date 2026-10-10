output "alb_dns_names" {
  description = "Public DNS names for both ALBs"

  value = {
    for name, lb in aws_lb.microservices :
    name => lb.dns_name
  }
}

output "alb_arns" {
  description = "ALB ARNs"

  value = {
    for name, lb in aws_lb.microservices :
    name => lb.arn
  }
}

output "target_group_arns" {
  description = "Blue and Green target group ARNs"

  value = {
    for name, tg in aws_lb_target_group.microservices :
    name => tg.arn
  }
}

output "listener_arns" {
  description = "Production HTTP listener ARNs"

  value = {
    for name, listener in aws_lb_listener.http :
    name => listener.arn
  }
}