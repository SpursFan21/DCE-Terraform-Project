resource "aws_ecr_repository" "microservices" {
  for_each = toset(["service-a", "service-b"])

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${each.key}"
  }
}