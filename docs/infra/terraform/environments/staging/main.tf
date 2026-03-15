# infra/terraform/environments/staging/main.tf
# MLM Staging Environment — root module
# Wires together: networking, aurora, redis, s3, ecr, ecs, cognito

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Remote state — replace bucket/key with your values
  backend "s3" {
    bucket         = "mlm-terraform-state"          # Create this manually first
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "mlm-terraform-locks"          # DynamoDB for state locking
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# ─────────────────────────────────────────────
# Common Tags (applied to all resources)
# ─────────────────────────────────────────────
locals {
  environment = "staging"
  common_tags = {
    Project     = "mlm"
    Environment = local.environment
    ManagedBy   = "terraform"
    CostCenter  = var.cost_center
  }
}

# ─────────────────────────────────────────────
# SQS Queues (created before ECS — needed for IAM policies)
# ─────────────────────────────────────────────
resource "aws_sqs_queue" "workflow" {
  name                       = "mlm-${local.environment}-workflow-events.fifo"
  fifo_queue                 = true
  content_based_deduplication = true
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600  # 4 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.workflow_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.common_tags
}

resource "aws_sqs_queue" "workflow_dlq" {
  name       = "mlm-${local.environment}-workflow-events-dlq.fifo"
  fifo_queue = true
  message_retention_seconds = 1209600  # 14 days

  tags = local.common_tags
}

resource "aws_sqs_queue" "monitoring_ingest" {
  name                       = "mlm-${local.environment}-monitoring-ingest"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.monitoring_ingest_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.common_tags
}

resource "aws_sqs_queue" "monitoring_ingest_dlq" {
  name                      = "mlm-${local.environment}-monitoring-ingest-dlq"
  message_retention_seconds = 1209600

  tags = local.common_tags
}

resource "aws_sqs_queue" "notifications" {
  name                       = "mlm-${local.environment}-notifications"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400  # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notifications_dlq.arn
    maxReceiveCount     = 5
  })

  tags = local.common_tags
}

resource "aws_sqs_queue" "notifications_dlq" {
  name                      = "mlm-${local.environment}-notifications-dlq"
  message_retention_seconds = 1209600

  tags = local.common_tags
}

locals {
  sqs_queue_arns = [
    aws_sqs_queue.workflow.arn,
    aws_sqs_queue.monitoring_ingest.arn,
    aws_sqs_queue.notifications.arn
  ]
}

# ─────────────────────────────────────────────
# RDS Enhanced Monitoring Role
# ─────────────────────────────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "mlm-${local.environment}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# SNS Topic for CloudWatch Alarms
resource "aws_sns_topic" "alarms" {
  name = "mlm-${local.environment}-alarms"
  tags = local.common_tags
}

# ─────────────────────────────────────────────
# Module: Networking
# ─────────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  project     = "mlm"
  environment = local.environment
  aws_region  = var.aws_region
  common_tags = local.common_tags

  vpc_cidr           = "10.0.0.0/16"
  availability_zones = var.availability_zones

  public_subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  private_data_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]

  nat_gateway_count = 1  # Staging: single NAT to save cost (~$32/mo)
}

# ─────────────────────────────────────────────
# Module: S3 Buckets
# ─────────────────────────────────────────────
module "s3" {
  source = "../../modules/s3"

  project     = "mlm"
  environment = local.environment
  common_tags = local.common_tags

  allowed_cors_origins = var.allowed_cors_origins
}

# ─────────────────────────────────────────────
# Module: ECR Repositories
# ─────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  project     = "mlm"
  environment = local.environment
  common_tags = local.common_tags

  cicd_role_arns = var.cicd_role_arns
}

# ─────────────────────────────────────────────
# Module: Aurora PostgreSQL
# ─────────────────────────────────────────────
module "aurora" {
  source = "../../modules/aurora"

  project     = "mlm"
  environment = local.environment
  common_tags = local.common_tags

  private_data_subnet_ids = module.networking.private_data_subnet_ids
  sg_aurora_id            = module.networking.sg_aurora_id
  rds_monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  alarm_sns_topic_arns    = [aws_sns_topic.alarms.arn]

  # 0 ACU = true zero cost when idle (scales to 0, pauses after 5 min inactivity)
  # Resume time: ~15 seconds — acceptable for staging
  # Requires Aurora PostgreSQL 16.3+
  aurora_min_acu            = 0      # Pauses to $0 compute when idle
  aurora_max_acu            = 8      # Caps at 8 ACU for staging
  aurora_auto_pause_seconds = 300    # Pause after 5 minutes idle
  reader_instance_count     = 0      # No reader for staging (writer handles all reads)
                                     # NOTE: reader instance prevents auto-pause;
                                     # set to 0 to enable true zero-cost idle
  backup_retention_days     = 7
}

# Store reader URL as separate secret for DES
resource "aws_secretsmanager_secret" "aurora_reader" {
  name                    = "mlm/${local.environment}/db/reader"
  description             = "MLM Aurora reader endpoint for DES"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "aurora_reader" {
  secret_id = aws_secretsmanager_secret.aurora_reader.id
  secret_string = jsonencode({
    url = "postgresql://${module.aurora.cluster_reader_endpoint}:5432/mlm"
    # Note: actual credentials fetched from master secret; reader uses same credentials
    # In practice, create a separate read-only IAM-authenticated user
  })
}

# ─────────────────────────────────────────────
# Module: Redis
# ─────────────────────────────────────────────
module "redis" {
  source = "../../modules/redis"

  project     = "mlm"
  environment = local.environment
  common_tags = local.common_tags

  private_data_subnet_ids = module.networking.private_data_subnet_ids
  sg_redis_id             = module.networking.sg_redis_id
  alarm_sns_topic_arns    = [aws_sns_topic.alarms.arn]

  # Staging: smallest instance, single node
  node_type          = "cache.t3.micro"
  num_cache_clusters = 1
}

# ─────────────────────────────────────────────
# Module: Cognito (SaaS IdP)
# ─────────────────────────────────────────────
module "cognito" {
  source = "../../modules/cognito"

  project     = "mlm"
  environment = local.environment
  aws_region  = var.aws_region
  common_tags = local.common_tags

  web_callback_urls = var.web_callback_urls
  web_logout_urls   = var.web_logout_urls
}

# ─────────────────────────────────────────────
# Module: ECS Fargate
# ─────────────────────────────────────────────
module "ecs" {
  source = "../../modules/ecs"

  project     = "mlm"
  environment = local.environment
  aws_region  = var.aws_region
  common_tags = local.common_tags

  # Networking
  vpc_id                 = module.networking.vpc_id
  public_subnet_ids      = module.networking.public_subnet_ids
  private_app_subnet_ids = module.networking.private_app_subnet_ids
  sg_alb_id              = module.networking.sg_alb_id
  sg_api_id              = module.networking.sg_api_id
  sg_des_id              = module.networking.sg_des_id
  sg_workers_id          = module.networking.sg_workers_id

  # TLS
  acm_certificate_arn = var.acm_certificate_arn

  # Container images
  ecr_api_url    = module.ecr.repository_urls["api"]
  ecr_des_url    = module.ecr.repository_urls["des"]
  ecr_worker_url = module.ecr.repository_urls["worker"]
  image_tag      = var.image_tag

  # Secrets
  aurora_secret_arn        = module.aurora.secret_arn
  aurora_reader_secret_arn = aws_secretsmanager_secret.aurora_reader.arn
  redis_secret_arn         = module.redis.secret_arn
  secrets_manager_arns = [
    module.aurora.secret_arn,
    aws_secretsmanager_secret.aurora_reader.arn,
    module.redis.secret_arn,
    module.cognito.service_client_secret_arn
  ]
  kms_key_arns = [
    module.aurora.kms_key_arn,
    module.s3.artifacts_kms_key_arn,
    module.s3.audit_kms_key_arn
  ]
  sqs_queue_arns = local.sqs_queue_arns

  # S3
  s3_artifacts_bucket           = module.s3.artifacts_bucket
  s3_artifacts_bucket_arn       = module.s3.artifacts_bucket_arn
  s3_reports_bucket             = module.s3.reports_bucket
  s3_reports_bucket_arn         = "${module.s3.artifacts_bucket_arn}"  # reuse ARN pattern
  s3_audit_archive_bucket       = module.s3.audit_archive_bucket
  s3_audit_archive_bucket_arn   = "${module.s3.artifacts_bucket_arn}"
  s3_upload_staging_bucket      = module.s3.upload_staging_bucket
  s3_upload_staging_bucket_arn  = "${module.s3.artifacts_bucket_arn}"

  # OIDC (Cognito for SaaS; customer replaces with their own for self-hosted)
  oidc_issuer_url = module.cognito.oidc_issuer_url
  oidc_audience   = module.cognito.web_client_id

  # App config
  log_level      = "INFO"
  fail_open_mode = true   # DES: fail open for staging

  # Sizing (staging: minimal)
  api_cpu           = 512
  api_memory        = 1024
  api_desired_count = 1
  api_min_count     = 1
  api_max_count     = 5

  des_cpu           = 256
  des_memory        = 512
  des_desired_count = 1

  worker_cpu           = 512
  worker_memory        = 1024
  worker_desired_count = 1
}
