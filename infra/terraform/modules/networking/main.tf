# infra/terraform/modules/networking/main.tf
# MLM Platform — VPC, Subnets, NAT Gateway, Security Groups
# All values injected via variables — no hardcoded IDs or CIDRs

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ─────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

# ─────────────────────────────────────────────
# Internet Gateway
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

# ─────────────────────────────────────────────
# Public Subnets (2 AZs — ALB, NAT)
# ─────────────────────────────────────────────
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false  # No auto-assign; controlled explicitly

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

# ─────────────────────────────────────────────
# Private App Subnets (2 AZs — ECS tasks)
# ─────────────────────────────────────────────
resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-private-app-${var.availability_zones[count.index]}"
    Tier = "private-app"
  })
}

# ─────────────────────────────────────────────
# Private Data Subnets (2 AZs — Aurora, Redis)
# ─────────────────────────────────────────────
resource "aws_subnet" "private_data" {
  count             = length(var.private_data_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-private-data-${var.availability_zones[count.index]}"
    Tier = "private-data"
  })
}

# ─────────────────────────────────────────────
# NAT Gateway (single AZ for staging; HA for prod via count)
# ─────────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = var.nat_gateway_count
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-nat-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "main" {
  count         = var.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-nat-${count.index}"
  })
}

# ─────────────────────────────────────────────
# Route Tables
# ─────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  count  = var.nat_gateway_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-rt-private-app-${count.index}"
  })
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[min(count.index, var.nat_gateway_count - 1)].id
}

resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-rt-private-data"
  })
  # No outbound internet route for data tier — intentional
}

resource "aws_route_table_association" "private_data" {
  count          = length(aws_subnet.private_data)
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data.id
}

# ─────────────────────────────────────────────
# S3 Gateway VPC Endpoint (free; keeps S3 traffic off internet)
# ─────────────────────────────────────────────
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private_app[*].id,
    [aws_route_table.private_data.id]
  )

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-vpce-s3"
  })
}

# ─────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────

# ALB — accepts HTTPS from internet
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-sg-alb"
  description = "MLM Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP redirect to HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.common_tags, { Name = "${var.project}-${var.environment}-sg-alb" })
}

# API — accepts from ALB only
resource "aws_security_group" "api" {
  name        = "${var.project}-${var.environment}-sg-api"
  description = "MLM API ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "API traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound (NAT → internet for AWS APIs)"
  }

  tags = merge(var.common_tags, { Name = "${var.project}-${var.environment}-sg-api" })
}

# DES — accepts from API + external deployments (separate SG for independent scaling)
resource "aws_security_group" "des" {
  name        = "${var.project}-${var.environment}-sg-des"
  description = "MLM Deployment Eligibility Service"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # DES is public-facing via ALB
    description = "DES eligibility API — called by CI/CD pipelines"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.project}-${var.environment}-sg-des" })
}

# Workers — Celery workers, no inbound
resource "aws_security_group" "workers" {
  name        = "${var.project}-${var.environment}-sg-workers"
  description = "MLM Celery worker tasks"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.project}-${var.environment}-sg-workers" })
}

# Aurora — accepts from API + DES + Workers SGs only
resource "aws_security_group" "aurora" {
  name        = "${var.project}-${var.environment}-sg-aurora"
  description = "MLM Aurora PostgreSQL cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [
      aws_security_group.api.id,
      aws_security_group.des.id,
      aws_security_group.workers.id
    ]
    description = "PostgreSQL from app tier only"
  }

  tags = merge(var.common_tags, { Name = "${var.project}-${var.environment}-sg-aurora" })
}

# Redis — accepts from API + DES + Workers SGs only
resource "aws_security_group" "redis" {
  name        = "${var.project}-${var.environment}-sg-redis"
  description = "MLM ElastiCache Redis cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"
    security_groups = [
      aws_security_group.api.id,
      aws_security_group.des.id,
      aws_security_group.workers.id
    ]
    description = "Redis from app tier only"
  }

  tags = merge(var.common_tags, { Name = "${var.project}-${var.environment}-sg-redis" })
}
