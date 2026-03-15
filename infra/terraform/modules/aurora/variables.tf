# infra/terraform/modules/aurora/variables.tf

variable "project"     { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string); default = {} }

variable "private_data_subnet_ids" {
  type        = list(string)
  description = "Private data subnet IDs for Aurora subnet group"
}

variable "sg_aurora_id" {
  type        = string
  description = "Aurora security group ID"
}

variable "db_name" {
  type        = string
  default     = "mlm"
  description = "Default database name"
}

variable "db_master_username" {
  type        = string
  default     = "mlm_master"
  description = "Aurora master username (not used for app connections — use IAM auth)"
}

variable "aurora_min_acu" {
  type        = number
  default     = 0.5
  description = "Minimum Aurora Capacity Units. 0.5 for staging (near-zero idle cost)"
}

variable "aurora_max_acu" {
  type        = number
  default     = 16
  description = "Maximum Aurora Capacity Units. 16 for staging, 128 for prod"
}

variable "reader_instance_count" {
  type        = number
  default     = 1
  description = "Number of reader instances. 1 for staging, 2 for prod"
}

variable "backup_retention_days" {
  type        = number
  default     = 7
  description = "Automated backup retention. 7 for staging, 35 for prod"
}

variable "rds_monitoring_role_arn" {
  type        = string
  description = "IAM role ARN for RDS enhanced monitoring"
}

variable "alarm_sns_topic_arns" {
  type        = list(string)
  default     = []
  description = "SNS topic ARNs for CloudWatch alarms"
}


# infra/terraform/modules/aurora/outputs.tf

output "cluster_endpoint" {
  value       = aws_rds_cluster.main.endpoint
  description = "Aurora writer endpoint"
  sensitive   = true
}

output "cluster_reader_endpoint" {
  value       = aws_rds_cluster.main.reader_endpoint
  description = "Aurora reader endpoint (load-balanced across all readers)"
  sensitive   = true
}

output "cluster_identifier" {
  value       = aws_rds_cluster.main.cluster_identifier
  description = "Aurora cluster identifier"
}

output "secret_arn" {
  value       = aws_secretsmanager_secret.aurora_master.arn
  description = "Secrets Manager ARN for master credentials"
}

output "kms_key_arn" {
  value       = aws_kms_key.aurora.arn
  description = "KMS key ARN for Aurora encryption"
}
