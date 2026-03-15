# infra/terraform/modules/aurora/outputs.tf

output "cluster_endpoint" {
  value       = aws_rds_cluster.main.endpoint
  description = "Aurora writer endpoint"
  sensitive   = true
}

output "cluster_reader_endpoint" {
  value       = aws_rds_cluster.main.reader_endpoint
  description = "Aurora reader endpoint"
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

output "auto_pause_enabled" {
  value       = var.aurora_min_acu == 0 ? true : false
  description = "Whether auto-pause is enabled (true when min_acu = 0)"
}
