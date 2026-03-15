# infra/terraform/modules/aurora/main.tf
# MLM Platform — Aurora PostgreSQL Serverless v2 cluster
# Schema-per-tenant; all credentials via Secrets Manager

terraform {
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.5" }
  }
}

# ─────────────────────────────────────────────
# KMS Key for Aurora encryption
# ─────────────────────────────────────────────
resource "aws_kms_key" "aurora" {
  description             = "MLM Aurora PostgreSQL encryption key - ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-kms-aurora"
  })
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.project}-${var.environment}-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}

# ─────────────────────────────────────────────
# Master password (stored in Secrets Manager — never in TF state)
# ─────────────────────────────────────────────
resource "random_password" "aurora_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "aurora_master" {
  name                    = "${var.project}/${var.environment}/db/master"
  description             = "MLM Aurora master credentials"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7
  kms_key_id              = aws_kms_key.aurora.arn

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "aurora_master" {
  secret_id = aws_secretsmanager_secret.aurora_master.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.aurora_master.result
    host     = aws_rds_cluster.main.endpoint
    port     = 5432
    dbname   = var.db_name
    url      = "postgresql://${var.db_master_username}:${random_password.aurora_master.result}@${aws_rds_cluster.main.endpoint}:5432/${var.db_name}"
  })
}

# ─────────────────────────────────────────────
# Subnet group
# ─────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-aurora-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-aurora-subnet-group"
  })
}

# ─────────────────────────────────────────────
# Parameter group (PostgreSQL 15 tuning)
# ─────────────────────────────────────────────
resource "aws_rds_cluster_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-aurora-pg16"
  family = "aurora-postgresql16"  # Updated: 16.3+ required for 0 ACU support

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries > 1s
  }

  parameter {
    name  = "log_checkpoints"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = var.common_tags
}

# ─────────────────────────────────────────────
# Aurora Cluster (Serverless v2)
# Supports 0 ACU minimum + auto-pause (feature added November 2024)
# Requires: Aurora PostgreSQL 15.7+ / 16.3+
#
# Auto-pause behaviour:
#   min_capacity = 0  → cluster pauses after seconds_until_auto_pause idle
#   Paused state      → $0 compute cost (storage only)
#   Resume time       → ~15 seconds on next connection
#
# Use 0 ACU for: dev, staging, demo environments
# Use 2 ACU for: production (no cold start acceptable)
# ─────────────────────────────────────────────
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project}-${var.environment}-aurora"

  engine         = "aurora-postgresql"
  engine_version = "16.3"        # Minimum version required for 0 ACU support
  engine_mode    = "provisioned" # Required for Serverless v2

  database_name   = var.db_name
  master_username = var.db_master_username
  master_password = random_password.aurora_master.result

  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [var.sg_aurora_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name

  storage_encrypted = true
  kms_key_id        = aws_kms_key.aurora.arn

  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "02:00-03:00"
  preferred_maintenance_window = "sun:03:30-sun:04:30"

  deletion_protection       = var.environment == "prod" ? true : false
  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.project}-${var.environment}-final-${formatdate("YYYY-MM-DD", timestamp())}" : null

  serverlessv2_scaling_configuration {
    min_capacity             = var.aurora_min_acu
    max_capacity             = var.aurora_max_acu
    # seconds_until_auto_pause only applies when min_capacity = 0
    # Range: 300 (5 min) to 86400 (1 day). Ignored when min_capacity > 0.
    seconds_until_auto_pause = var.aurora_min_acu == 0 ? var.aurora_auto_pause_seconds : null
  }

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-aurora"
  })

  lifecycle {
    ignore_changes = [master_password] # Managed via Secrets Manager rotation
  }
}

# ─────────────────────────────────────────────
# Aurora Instances
# ─────────────────────────────────────────────

# Writer instance
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.project}-${var.environment}-aurora-writer"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = var.rds_monitoring_role_arn

  auto_minor_version_upgrade = true

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-aurora-writer"
    Role = "writer"
  })
}

# Reader instance (for API read queries + DES queries)
resource "aws_rds_cluster_instance" "reader" {
  count              = var.reader_instance_count
  identifier         = "${var.project}-${var.environment}-aurora-reader-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = var.rds_monitoring_role_arn

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-aurora-reader-${count.index}"
    Role = "reader"
  })
}

# ─────────────────────────────────────────────
# CloudWatch Alarms
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project}-${var.environment}-aurora-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora CPU above 80%"
  alarm_actions       = var.alarm_sns_topic_arns

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "aurora_free_storage" {
  alarm_name          = "${var.project}-${var.environment}-aurora-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeLocalStorage"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120  # 5 GB in bytes
  alarm_description   = "Aurora free storage below 5GB"
  alarm_actions       = var.alarm_sns_topic_arns

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.writer.identifier
  }

  tags = var.common_tags
}
