# infra/terraform/environments/staging/variables.tf

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "cost_center" {
  type        = string
  description = "FinOps cost center code"
  default     = "mlm-staging"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS. Create via AWS Console or Terraform before deploying."
}

variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy"
  default     = "latest"
}

variable "web_callback_urls" {
  type    = list(string)
  default = ["https://staging.mlm.yourdomain.com/auth/callback", "http://localhost:3000/auth/callback"]
}

variable "web_logout_urls" {
  type    = list(string)
  default = ["https://staging.mlm.yourdomain.com/auth/logout", "http://localhost:3000/auth/logout"]
}

variable "allowed_cors_origins" {
  type    = list(string)
  default = ["https://staging.mlm.yourdomain.com", "http://localhost:3000"]
}

variable "cicd_role_arns" {
  type        = list(string)
  description = "IAM role ARNs for GitHub Actions OIDC (can push to ECR)"
  default     = []
}


# infra/terraform/environments/staging/outputs.tf

output "alb_dns_name" {
  value       = module.ecs.alb_dns_name
  description = "ALB DNS name — point your staging subdomain here via CNAME"
}

output "aurora_endpoint" {
  value     = module.aurora.cluster_endpoint
  sensitive = true
}

output "ecr_repositories" {
  value = module.ecr.repository_urls
}

output "cognito_oidc_issuer" {
  value       = module.cognito.oidc_issuer_url
  description = "Set as OIDC_ISSUER_URL in app config"
}

output "cognito_web_client_id" {
  value = module.cognito.web_client_id
}

output "s3_buckets" {
  value = {
    artifacts     = module.s3.artifacts_bucket
    reports       = module.s3.reports_bucket
    audit_archive = module.s3.audit_archive_bucket
    frontend      = module.s3.frontend_bucket
    upload_staging = module.s3.upload_staging_bucket
  }
}


# infra/terraform/environments/staging/terraform.tfvars.example
# Copy to terraform.tfvars and fill in values
# DO NOT commit terraform.tfvars to git

# aws_region           = "us-east-1"
# availability_zones   = ["us-east-1a", "us-east-1b"]
# acm_certificate_arn  = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
# image_tag            = "staging-abc1234"
# cicd_role_arns       = ["arn:aws:iam::123456789012:role/mlm-github-actions"]
