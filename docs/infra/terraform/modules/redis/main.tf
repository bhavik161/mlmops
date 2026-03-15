# infra/terraform/modules/redis/main.tf
# MLM Platform — ElastiCache Redis 7
# Used for: DES eligibility cache, session tokens, rate limiting

terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.5" }
  }
}

# ─────────────────────────────────────────────
# KMS Key for Redis encryption at rest
# ─────────────────────────────────────────────
resource "aws_kms_key" "redis" {
  description             = "MLM Redis encryption key - ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-kms-redis"
  })
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${var.project}-${var.environment}-redis"
  target_key_id = aws_kms_key.redis.key_id
}

# ─────────────────────────────────────────────
# Auth Token (stored in Secrets Manager)
# ─────────────────────────────────────────────
resource "random_password" "redis_auth" {
  length  = 64
  special = false  # Redis AUTH token: alphanumeric only
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "${var.project}/${var.environment}/redis/auth-token"
  description             = "MLM Redis AUTH token"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7
  kms_key_id              = aws_kms_key.redis.arn

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth.result
    url        = "rediss://:${random_password.redis_auth.result}@${aws_elasticache_replication_group.main.primary_endpoint_address}:6379/0"
  })
}

# ─────────────────────────────────────────────
# Subnet group
# ─────────────────────────────────────────────
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-redis-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-redis-subnet-group"
  })
}

# ─────────────────────────────────────────────
# Parameter group
# ─────────────────────────────────────────────
resource "aws_elasticache_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-redis7"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"  # Evict LRU keys when memory full
  }

  parameter {
    name  = "notify-keyspace-events"
    value = ""  # Disabled (not needed for MLM)
  }

  tags = var.common_tags
}

# ─────────────────────────────────────────────
# Replication Group (cluster with failover)
# ─────────────────────────────────────────────
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project}-${var.environment}-redis"
  description          = "MLM Redis cache - ${var.environment}"

  node_type               = var.node_type    # cache.t3.micro for staging, cache.r7g.large for prod
  num_cache_clusters      = var.num_cache_clusters  # 2 for staging (primary + replica), 3+ for prod
  port                    = 6379
  parameter_group_name    = aws_elasticache_parameter_group.main.name
  subnet_group_name       = aws_elasticache_subnet_group.main.name
  security_group_ids      = [var.sg_redis_id]

  # Encryption
  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true   # TLS (requires rediss:// URL)
  kms_key_id                  = aws_kms_key.redis.arn
  auth_token                  = random_password.redis_auth.result

  # Failover (disabled for staging single-node, enabled for prod)
  automatic_failover_enabled  = var.num_cache_clusters > 1 ? true : false
  multi_az_enabled            = var.num_cache_clusters > 1 ? true : false

  # Maintenance
  snapshot_retention_limit    = var.environment == "prod" ? 7 : 1
  snapshot_window             = "02:30-03:30"
  maintenance_window          = "sun:04:00-sun:05:00"

  auto_minor_version_upgrade  = true
  apply_immediately           = var.environment == "prod" ? false : true

  log_delivery_configuration {
    destination      = "/aws/elasticache/${var.project}-${var.environment}/slow-logs"
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-redis"
  })

  lifecycle {
    ignore_changes = [auth_token]  # Managed via Secrets Manager rotation
  }
}

# ─────────────────────────────────────────────
# CloudWatch Alarms
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.project}-${var.environment}-redis-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Redis memory usage above 80%"
  alarm_actions       = var.alarm_sns_topic_arns

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.main.id
  }

  tags = var.common_tags
}


# infra/terraform/modules/redis/variables.tf

variable "project"     { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string); default = {} }

variable "private_data_subnet_ids" { type = list(string) }
variable "sg_redis_id"             { type = string }

variable "node_type" {
  type    = string
  default = "cache.t3.micro"
  description = "Instance type. cache.t3.micro for staging, cache.r7g.large for prod"
}

variable "num_cache_clusters" {
  type    = number
  default = 1
  description = "Number of cache nodes. 1 for staging, 2+ for prod (enables HA)"
}

variable "alarm_sns_topic_arns" {
  type    = list(string)
  default = []
}


# infra/terraform/modules/redis/outputs.tf

output "primary_endpoint" {
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  description = "Redis primary endpoint"
  sensitive   = true
}

output "secret_arn" {
  value       = aws_secretsmanager_secret.redis_auth.arn
  description = "Secrets Manager ARN for Redis auth token"
}

output "replication_group_id" {
  value       = aws_elasticache_replication_group.main.id
}
