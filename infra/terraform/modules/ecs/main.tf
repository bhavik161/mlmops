# infra/terraform/modules/ecs/main.tf
# MLM Platform — ECS Fargate Cluster + Services
# Services: api, des (Deployment Eligibility Service), worker (Celery)

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# ─────────────────────────────────────────────
# ECS Cluster
# ─────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-ecs"
  })
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ─────────────────────────────────────────────
# CloudWatch Log Groups (one per service)
# ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "services" {
  for_each = toset(["api", "des", "worker"])

  name              = "/mlm/${var.environment}/${each.value}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

# ─────────────────────────────────────────────
# Task Execution Role (shared — pulls ECR, writes logs)
# ─────────────────────────────────────────────
resource "aws_iam_role" "task_execution" {
  name = "${var.project}-${var.environment}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "task_execution_basic" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow execution role to fetch secrets (DB password, Redis auth, etc.)
resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "secrets-access"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "kms:Decrypt"]
      Resource = var.secrets_manager_arns
    }]
  })
}

# ─────────────────────────────────────────────
# Task Roles (per-service — least privilege)
# ─────────────────────────────────────────────

# API Task Role
resource "aws_iam_role" "api_task" {
  name = "${var.project}-${var.environment}-api-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "api_task_s3" {
  name = "s3-presigned-urls"
  role = aws_iam_role.api_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.s3_upload_staging_bucket_arn}/*",
          "${var.s3_reports_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.s3_artifacts_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = var.kms_key_arns
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueUrl"]
        Resource = var.sqs_queue_arns
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.secrets_manager_arns
      }
    ]
  })
}

# DES Task Role (read-only — queries Aurora read replica + Redis)
resource "aws_iam_role" "des_task" {
  name = "${var.project}-${var.environment}-des-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "des_task" {
  name = "des-minimal"
  role = aws_iam_role.des_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.secrets_manager_arns
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]  # For eligibility check audit log
        Resource = var.sqs_queue_arns
      }
    ]
  })
}

# Worker Task Role (broader access — S3 artifact processing, SageMaker, SQS)
resource "aws_iam_role" "worker_task" {
  name = "${var.project}-${var.environment}-worker-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "worker_task" {
  name = "worker-access"
  role = aws_iam_role.worker_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:CopyObject", "s3:DeleteObject"
        ]
        Resource = [
          "${var.s3_upload_staging_bucket_arn}/*",
          "${var.s3_artifacts_bucket_arn}/*",
          "${var.s3_audit_archive_bucket_arn}/*",
          "${var.s3_reports_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage", "sqs:DeleteMessage",
          "sqs:GetQueueAttributes", "sqs:SendMessage"
        ]
        Resource = var.sqs_queue_arns
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.secrets_manager_arns
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = var.kms_key_arns
      },
      # SageMaker integration (for MLflow run fetching + SM Model Monitor)
      {
        Effect = "Allow"
        Action = [
          "sagemaker:ListExperiments",
          "sagemaker:ListTrials",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:ListModelPackages",
          "sagemaker:DescribeModelPackage",
          "sagemaker:AddTags",
          "sagemaker:ListTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# Application Load Balancer
# ─────────────────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  access_logs {
    bucket  = var.s3_artifacts_bucket  # Reuse artifacts bucket for ALB logs
    prefix  = "alb-logs"
    enabled = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-alb"
  })
}

# HTTPS Listener (main traffic)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  tags = var.common_tags
}

# HTTP → HTTPS redirect
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ─────────────────────────────────────────────
# Target Groups
# ─────────────────────────────────────────────
resource "aws_lb_target_group" "api" {
  name        = "${var.project}-${var.environment}-api"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Required for Fargate

  health_check {
    enabled             = true
    path                = "/health/live"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = var.common_tags
}

resource "aws_lb_target_group" "des" {
  name        = "${var.project}-${var.environment}-des"
  port        = 8001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health/live"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15   # More frequent — DES is critical path
    timeout             = 3
    matcher             = "200"
  }

  deregistration_delay = 10  # DES: faster deregistration for rolling deploys

  tags = var.common_tags
}

# DES gets its own ALB listener rule (path-based routing)
resource "aws_lb_listener_rule" "des" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.des.arn
  }

  condition {
    path_pattern {
      values = ["/api/v*/deployment/eligibility*"]
    }
  }
}

# ─────────────────────────────────────────────
# ECS Task Definitions
# ─────────────────────────────────────────────

# API Task Definition
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project}-${var.environment}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.api_task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${var.ecr_api_url}:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = 8000, protocol = "tcp" }
      ]

      environment = [
        { name = "APP_ENV",     value = var.environment },
        { name = "PORT",        value = "8000" },
        { name = "LOG_LEVEL",   value = var.log_level },
        { name = "AWS_REGION",  value = var.aws_region },
        # Bucket names (not secrets — just config)
        { name = "S3_ARTIFACTS_BUCKET",     value = var.s3_artifacts_bucket },
        { name = "S3_REPORTS_BUCKET",       value = var.s3_reports_bucket },
        { name = "S3_AUDIT_ARCHIVE_BUCKET", value = var.s3_audit_archive_bucket },
        { name = "S3_UPLOAD_STAGING_BUCKET", value = var.s3_upload_staging_bucket },
        # OIDC config (not secret — public endpoint)
        { name = "OIDC_ISSUER_URL", value = var.oidc_issuer_url },
        { name = "OIDC_AUDIENCE",   value = var.oidc_audience },
        # Fail mode
        { name = "FAIL_OPEN_MODE", value = tostring(var.fail_open_mode) }
      ]

      secrets = [
        # Credentials fetched from Secrets Manager at container start
        { name = "DATABASE_URL",      valueFrom = "${var.aurora_secret_arn}:url::" },
        { name = "DATABASE_URL_READ", valueFrom = "${var.aurora_reader_secret_arn}:url::" },
        { name = "REDIS_URL",         valueFrom = "${var.redis_secret_arn}:url::" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["api"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/health/live || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = var.common_tags
}

# DES Task Definition
resource "aws_ecs_task_definition" "des" {
  family                   = "${var.project}-${var.environment}-des"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.des_cpu
  memory                   = var.des_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.des_task.arn

  container_definitions = jsonencode([
    {
      name      = "des"
      image     = "${var.ecr_des_url}:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = 8001, protocol = "tcp" }
      ]

      environment = [
        { name = "APP_ENV",         value = var.environment },
        { name = "PORT",            value = "8001" },
        { name = "LOG_LEVEL",       value = var.log_level },
        { name = "AWS_REGION",      value = var.aws_region },
        { name = "OIDC_ISSUER_URL", value = var.oidc_issuer_url },
        { name = "OIDC_AUDIENCE",   value = var.oidc_audience },
        { name = "FAIL_OPEN_MODE",  value = tostring(var.fail_open_mode) },
        { name = "CACHE_TTL_SECONDS", value = "300" }
      ]

      secrets = [
        { name = "DATABASE_URL_READ", valueFrom = "${var.aurora_reader_secret_arn}:url::" },
        { name = "REDIS_URL",         valueFrom = "${var.redis_secret_arn}:url::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["des"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "des"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8001/health/live || exit 1"]
        interval    = 15
        timeout     = 3
        retries     = 2
        startPeriod = 30
      }
    }
  ])

  tags = var.common_tags
}

# Worker Task Definition (Celery)
resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.project}-${var.environment}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.worker_task.arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = "${var.ecr_worker_url}:${var.image_tag}"
      essential = true
      # No port mappings — workers don't accept inbound connections

      command = ["celery", "-A", "app.worker.celery_app", "worker",
                 "--loglevel=info", "--concurrency=4",
                 "-Q", "workflow,notifications,monitoring,default"]

      environment = [
        { name = "APP_ENV",    value = var.environment },
        { name = "LOG_LEVEL",  value = var.log_level },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "S3_ARTIFACTS_BUCKET",      value = var.s3_artifacts_bucket },
        { name = "S3_AUDIT_ARCHIVE_BUCKET",  value = var.s3_audit_archive_bucket },
        { name = "S3_UPLOAD_STAGING_BUCKET", value = var.s3_upload_staging_bucket }
      ]

      secrets = [
        { name = "DATABASE_URL", valueFrom = "${var.aurora_secret_arn}:url::" },
        { name = "REDIS_URL",    valueFrom = "${var.redis_secret_arn}:url::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services["worker"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])

  tags = var.common_tags
}

# ─────────────────────────────────────────────
# ECS Services
# ─────────────────────────────────────────────
resource "aws_ecs_service" "api" {
  name            = "${var.project}-${var.environment}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
    base              = 1
  }

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.sg_api_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8000
  }

  deployment_configuration {
    minimum_healthy_percent = 50
    maximum_percent         = 200
    deployment_circuit_breaker {
      enable   = true
      rollback = true  # Auto-rollback on deployment failure
    }
  }

  deployment_controller {
    type = "ECS"
  }

  # Ignore desired_count changes (managed by auto-scaling)
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_lb_listener.https]
  tags = var.common_tags
}

resource "aws_ecs_service" "des" {
  name            = "${var.project}-${var.environment}-des"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.des.arn
  desired_count   = var.des_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
    base              = 2  # Always keep 2 DES tasks minimum
  }

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.sg_des_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.des.arn
    container_name   = "des"
    container_port   = 8001
  }

  deployment_configuration {
    minimum_healthy_percent = 100  # DES: zero-downtime deploys (keep full capacity)
    maximum_percent         = 200
    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_lb_listener_rule.des]
  tags = var.common_tags
}

resource "aws_ecs_service" "worker" {
  name            = "${var.project}-${var.environment}-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"  # Workers can use Spot (SQS retries on preemption)
    weight            = 80
    base              = 0
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 20
    base              = 1
  }

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.sg_workers_id]
    assign_public_ip = false
  }

  deployment_configuration {
    minimum_healthy_percent = 50
    maximum_percent         = 200
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  tags = var.common_tags
}

# ─────────────────────────────────────────────
# Auto Scaling
# ─────────────────────────────────────────────
resource "aws_appautoscaling_target" "api" {
  max_capacity       = var.api_max_count
  min_capacity       = var.api_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "${var.project}-${var.environment}-api-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70  # Scale when CPU > 70%
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
