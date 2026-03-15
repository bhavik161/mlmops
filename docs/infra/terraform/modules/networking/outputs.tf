# infra/terraform/modules/networking/outputs.tf

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Public subnet IDs"
}

output "private_app_subnet_ids" {
  value       = aws_subnet.private_app[*].id
  description = "Private app subnet IDs (ECS tasks)"
}

output "private_data_subnet_ids" {
  value       = aws_subnet.private_data[*].id
  description = "Private data subnet IDs (Aurora, Redis)"
}

output "sg_alb_id" {
  value       = aws_security_group.alb.id
  description = "ALB security group ID"
}

output "sg_api_id" {
  value       = aws_security_group.api.id
  description = "API ECS tasks security group ID"
}

output "sg_des_id" {
  value       = aws_security_group.des.id
  description = "DES ECS tasks security group ID"
}

output "sg_workers_id" {
  value       = aws_security_group.workers.id
  description = "Celery workers security group ID"
}

output "sg_aurora_id" {
  value       = aws_security_group.aurora.id
  description = "Aurora security group ID"
}

output "sg_redis_id" {
  value       = aws_security_group.redis.id
  description = "Redis security group ID"
}
