output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of both public subnets"
  value       = aws_subnet.public[*].id
}

output "vpc_cidr" {
  description = "VPC CIDR range"
  value       = aws_vpc.main.cidr_block
}