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
  description = "Aurora master username"
}

variable "aurora_min_acu" {
  type        = number
  default     = 0
  description = <<EOT
Minimum Aurora Capacity Units.
  0   = scales to zero when idle (auto-pause) — dev/staging (zero compute cost when paused)
  0.5 = always warm, no cold start — shared staging with SLA requirements
  2   = production minimum
Requires Aurora PostgreSQL 16.3+ for 0 ACU support.
EOT

  validation {
    condition     = var.aurora_min_acu >= 0 && var.aurora_min_acu <= 256
    error_message = "aurora_min_acu must be between 0 and 256."
  }
}

variable "aurora_max_acu" {
  type        = number
  default     = 8
  description = "Maximum Aurora Capacity Units. 8 for staging, 128 for prod."

  validation {
    condition     = var.aurora_max_acu >= 1 && var.aurora_max_acu <= 256
    error_message = "aurora_max_acu must be between 1 and 256."
  }
}

variable "aurora_auto_pause_seconds" {
  type        = number
  default     = 300
  description = <<EOT
Seconds of inactivity before cluster pauses. Only applies when aurora_min_acu = 0.
  300   =  5 minutes (default — good for dev)
  900   = 15 minutes (good for staging with occasional use)
  3600  =  1 hour    (good for demo environments)
  86400 =  1 day     (maximum allowed)
Note: Resume time is ~15 seconds. Acceptable for dev/staging.
EOT

  validation {
    condition     = var.aurora_auto_pause_seconds >= 300 && var.aurora_auto_pause_seconds <= 86400
    error_message = "aurora_auto_pause_seconds must be between 300 (5 min) and 86400 (1 day)."
  }
}

variable "reader_instance_count" {
  type        = number
  default     = 0
  description = <<EOT
Number of reader instances.
  0 = no reader (dev/staging — saves cost; writer handles all reads)
  1 = one reader (staging with DES read replica)
  2 = two readers (production)
Note: When min_acu=0 and reader_count=0, the cluster can fully pause.
      A reader instance prevents auto-pause even when the writer is idle.
EOT
}

variable "backup_retention_days" {
  type        = number
  default     = 7
  description = "Automated backup retention. 7 for staging, 35 for prod."
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

