# infra/terraform/modules/ecr/main.tf
# MLM Platform — ECR Repositories
# One repo per service: api, des (Deployment Eligibility Service), worker

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

locals {
  repos = ["api", "des", "worker"]
}

resource "aws_ecr_repository" "repos" {
  for_each = toset(local.repos)

  name                 = "${var.project}/${each.value}"
  image_tag_mutability = "MUTABLE"  # Allow :latest and :staging tags

  image_scanning_configuration {
    scan_on_push = true  # ECR Enhanced Scanning (Snyk) on every push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project}-${each.value}"
    Service = each.value
  })
}

# Lifecycle policy: keep last 10 images per repo; delete untagged after 1 day
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = toset(local.repos)
  repository = aws_ecr_repository.repos[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 20 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "staging-", "prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Repository policy: allow CI/CD role to push; ECS task roles to pull
resource "aws_ecr_repository_policy" "repos" {
  for_each   = toset(local.repos)
  repository = aws_ecr_repository.repos[each.value].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCICDPush"
        Effect = "Allow"
        Principal = {
          AWS = var.cicd_role_arns
        }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
      }
    ]
  })
}


# infra/terraform/modules/ecr/variables.tf

variable "project"     { type = string; default = "mlm" }
variable "environment" { type = string }
variable "common_tags" { type = map(string); default = {} }

variable "cicd_role_arns" {
  type        = list(string)
  description = "IAM role ARNs allowed to push images (GitHub Actions OIDC role)"
  default     = []
}


# infra/terraform/modules/ecr/outputs.tf

output "repository_urls" {
  value = {
    for k, v in aws_ecr_repository.repos : k => v.repository_url
  }
  description = "ECR repository URLs by service name"
}

output "repository_arns" {
  value = {
    for k, v in aws_ecr_repository.repos : k => v.arn
  }
}
