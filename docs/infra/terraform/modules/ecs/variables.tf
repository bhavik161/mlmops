# infra/terraform/modules/ecs/variables.tf

variable "project"     { type = string; default = "mlm" }
variable "environment" { type = string }
variable "aws_region"  { type = string }
variable "common_tags" { type = map(string); default = {} }

# Networking
variable "vpc_id"                  { type = string }
variable "public_subnet_ids"       { type = list(string) }
variable "private_app_subnet_ids"  { type = list(string) }
variable "sg_alb_id"               { type = string }
variable "sg_api_id"               { type = string }
variable "sg_des_id"               { type = string }
variable "sg_workers_id"           { type = string }

# ACM certificate (HTTPS)
variable "acm_certificate_arn" { type = string }

# ECR image URLs
variable "ecr_api_url"    { type = string }
variable "ecr_des_url"    { type = string }
variable "ecr_worker_url" { type = string }
variable "image_tag"      { type = string; default = "latest" }

# Secrets
variable "aurora_secret_arn"        { type = string }
variable "aurora_reader_secret_arn" { type = string }
variable "redis_secret_arn"         { type = string }
variable "secrets_manager_arns"     { type = list(string); default = [] }
variable "kms_key_arns"             { type = list(string); default = [] }
variable "sqs_queue_arns"           { type = list(string); default = [] }

# S3 buckets
variable "s3_artifacts_bucket"         { type = string }
variable "s3_artifacts_bucket_arn"     { type = string }
variable "s3_reports_bucket"           { type = string }
variable "s3_reports_bucket_arn"       { type = string }
variable "s3_audit_archive_bucket"     { type = string }
variable "s3_audit_archive_bucket_arn" { type = string }
variable "s3_upload_staging_bucket"    { type = string }
variable "s3_upload_staging_bucket_arn" { type = string }

# OIDC
variable "oidc_issuer_url" { type = string }
variable "oidc_audience"   { type = string }

# App config
variable "log_level"      { type = string; default = "INFO" }
variable "fail_open_mode" { type = bool;   default = true }
variable "log_retention_days" { type = number; default = 30 }

# Sizing: API
variable "api_cpu"           { type = number; default = 512  }
variable "api_memory"        { type = number; default = 1024 }
variable "api_desired_count" { type = number; default = 2    }
variable "api_min_count"     { type = number; default = 1    }
variable "api_max_count"     { type = number; default = 20   }

# Sizing: DES
variable "des_cpu"           { type = number; default = 256  }
variable "des_memory"        { type = number; default = 512  }
variable "des_desired_count" { type = number; default = 2    }

# Sizing: Workers
variable "worker_cpu"           { type = number; default = 512  }
variable "worker_memory"        { type = number; default = 1024 }
variable "worker_desired_count" { type = number; default = 2    }


# infra/terraform/modules/ecs/outputs.tf

output "cluster_arn"  { value = aws_ecs_cluster.main.arn }
output "cluster_name" { value = aws_ecs_cluster.main.name }
output "alb_dns_name" { value = aws_lb.main.dns_name }
output "alb_arn"      { value = aws_lb.main.arn }

output "api_service_name"    { value = aws_ecs_service.api.name }
output "des_service_name"    { value = aws_ecs_service.des.name }
output "worker_service_name" { value = aws_ecs_service.worker.name }

output "api_task_role_arn"    { value = aws_iam_role.api_task.arn }
output "des_task_role_arn"    { value = aws_iam_role.des_task.arn }
output "worker_task_role_arn" { value = aws_iam_role.worker_task.arn }
