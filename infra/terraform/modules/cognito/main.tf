# infra/terraform/modules/cognito/main.tf
# MLM Platform — Cognito User Pool
# Default IdP for SaaS deployment.
# For customer-deployed: customers configure their own OIDC provider.
# Application code only needs OIDC_ISSUER_URL + OIDC_AUDIENCE — no Cognito SDK.

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-${var.environment}-users"

  # Username: email address
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # MFA — optional for staging, required for prod
  mfa_configuration = var.environment == "prod" ? "ON" : "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User attributes (standard + custom)
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    string_attribute_constraints {
      min_length = 5
      max_length = 254
    }
  }

  schema {
    name                = "tenant_id"
    attribute_data_type = "String"
    required            = false
    mutable             = true
    string_attribute_constraints {
      min_length = 36
      max_length = 36
    }
  }

  schema {
    name                = "roles"
    attribute_data_type = "String"
    required            = false
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  # JWT token config
  user_pool_add_ons {
    advanced_security_mode = var.environment == "prod" ? "ENFORCED" : "AUDIT"
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Deletion protection
  deletion_protection = var.environment == "prod" ? "ACTIVE" : "INACTIVE"

  tags = var.common_tags
}

# ─────────────────────────────────────────────
# User Pool Domain (for hosted UI + token endpoint)
# ─────────────────────────────────────────────
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project}-${var.environment}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────
# Resource Server (defines API scopes)
# ─────────────────────────────────────────────
resource "aws_cognito_resource_server" "api" {
  identifier   = "https://api.${var.project}.${var.environment}"
  name         = "MLM API"
  user_pool_id = aws_cognito_user_pool.main.id

  scope {
    scope_name        = "read"
    scope_description = "Read access to MLM API"
  }

  scope {
    scope_name        = "write"
    scope_description = "Write access to MLM API"
  }

  scope {
    scope_name        = "eligibility:read"
    scope_description = "DES eligibility check (service-to-service)"
  }

  scope {
    scope_name        = "ingest:write"
    scope_description = "Monitoring metric ingestion (service-to-service)"
  }
}

# ─────────────────────────────────────────────
# App Client — Web SPA (Authorization Code + PKCE)
# ─────────────────────────────────────────────
resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project}-${var.environment}-web"
  user_pool_id = aws_cognito_user_pool.main.id

  # SPA: no client secret (PKCE flow)
  generate_secret = false

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  callback_urls = var.web_callback_urls
  logout_urls   = var.web_logout_urls

  # Token validity
  access_token_validity  = 15    # 15 minutes
  id_token_validity      = 15
  refresh_token_validity = 480   # 8 hours

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "minutes"
  }

  # Prevent user existence errors leaking in auth responses
  prevent_user_existence_errors = "ENABLED"

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

# ─────────────────────────────────────────────
# App Client — Service-to-Service (Client Credentials)
# For CI/CD pipelines calling DES, monitoring ingestion
# ─────────────────────────────────────────────
resource "aws_cognito_user_pool_client" "service" {
  name         = "${var.project}-${var.environment}-service"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true  # M2M: uses client secret

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes = [
    "${aws_cognito_resource_server.api.identifier}/eligibility:read",
    "${aws_cognito_resource_server.api.identifier}/ingest:write"
  ]

  access_token_validity = 60  # 1 hour for service tokens

  token_validity_units {
    access_token = "minutes"
  }
}

# Store service client secret in Secrets Manager
resource "aws_secretsmanager_secret" "service_client" {
  name                    = "${var.project}/${var.environment}/cognito/service-client"
  description             = "Cognito service-to-service client credentials"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "service_client" {
  secret_id = aws_secretsmanager_secret.service_client.id
  secret_string = jsonencode({
    client_id     = aws_cognito_user_pool_client.service.id
    client_secret = aws_cognito_user_pool_client.service.client_secret
    token_url     = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/token"
  })
}


# infra/terraform/modules/cognito/variables.tf

variable "project"     { type = string; default = "mlm" }
variable "environment" { type = string }
variable "aws_region"  { type = string }
variable "common_tags" { type = map(string); default = {} }

variable "web_callback_urls" {
  type        = list(string)
  description = "Allowed callback URLs for the web app client"
  default     = ["https://app.mlm.yourdomain.com/auth/callback"]
}

variable "web_logout_urls" {
  type    = list(string)
  default = ["https://app.mlm.yourdomain.com/auth/logout"]
}


# infra/terraform/modules/cognito/outputs.tf

output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.main.arn
}

output "oidc_issuer_url" {
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
  description = "OIDC issuer URL — set as OIDC_ISSUER_URL env var"
}

output "web_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "service_client_id" {
  value = aws_cognito_user_pool_client.service.id
}

output "token_endpoint" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/token"
}

output "service_client_secret_arn" {
  value = aws_secretsmanager_secret.service_client.arn
}
