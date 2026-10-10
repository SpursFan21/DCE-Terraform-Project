module "networking" {
  source = "./modules/networking"

  project_name = "dce04"
  vpc_cidr     = "10.0.0.0/16"

  availability_zones = [
    "ap-southeast-2a",
    "ap-southeast-2b"
  ]
}

module "security" {
  source = "./modules/security"

  project_name   = "dce04"
  vpc_id         = module.networking.vpc_id
  container_port = 8080
}

module "ecr" {
  source = "./modules/ecr"

  project_name = "dce04"
}

module "alb" {
  source = "./modules/alb"

  project_name = "dce04"

  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids

  alb_security_group_ids = module.security.alb_security_group_ids

  container_port = 8080
}

module "ecs" {
  source = "./modules/ecs"

  project_name = "dce04"
  aws_region   = var.aws_region

  public_subnet_ids      = module.networking.public_subnet_ids
  ecs_security_group_ids = module.security.ecs_security_group_ids

  repository_urls   = module.ecr.repository_urls
  target_group_arns = module.alb.target_group_arns

  container_port = 8080
  desired_count  = 1

  depends_on = [module.alb]
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name = "dce04"

  cluster_name  = module.ecs.cluster_name
  service_names = module.ecs.service_names

  min_capacity = 1
  max_capacity = 2
}

data "aws_caller_identity" "current" {}

module "data" {
  source = "./modules/data"

  project_name  = "dce04"
  bucket_suffix = data.aws_caller_identity.current.account_id
}

module "cicd" {
  source = "./modules/cicd"

  project_name = "dce04"

  cluster_name      = module.ecs.cluster_name
  service_names     = module.ecs.service_names
  target_group_arns = module.alb.target_group_arns
  listener_arns     = module.alb.listener_arns

  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id

  repository_urls = module.ecr.repository_urls
  repository_arns = module.ecr.repository_arns

  artifacts_bucket_arn = module.data.artifacts_bucket_arn
}