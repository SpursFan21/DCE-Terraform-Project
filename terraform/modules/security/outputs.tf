output "alb_security_group_ids" {
  description = "Security group IDs for the two ALBs"
  value = {
    for name, sg in aws_security_group.alb : name => sg.id
  }
}

output "ecs_security_group_ids" {
  description = "Security group IDs for the two ECS services"
  value = {
    for name, sg in aws_security_group.ecs : name => sg.id
  }
}