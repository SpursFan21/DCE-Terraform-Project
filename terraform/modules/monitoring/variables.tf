variable "project_name" {
  description = "Project naming prefix"
  type        = string
}

variable "cluster_name" {
  description = "Existing ECS cluster name"
  type        = string
}

variable "service_names" {
  description = "ECS service names"
  type        = map(string)
}

variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 2
}