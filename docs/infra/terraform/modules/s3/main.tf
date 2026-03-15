# infra/terraform/modules/s3/main.tf
# MLM Platform — S3 Buckets
# Buckets: artifacts, reports, audit-archive, frontend, upload-staging
# All public access blocked; VPC endpoint enforced for app tier

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

locals {
  # All bucket names: mlm-{env}-{purpose}
  # Using account ID suffix prevents global naming conflicts
  bucket_suffix = "${var.environment}-${data.aws_caller_identity.current.account_id}"
  buckets = {
    artifacts     = "mlm-${local.bucket_suffix}-artifacts"
    reports       = "mlm-${local.bucket_suffix}-reports"
    audit_archive = "mlm-${local.bucket_suffix}-audit-archive"
    frontend      = "mlm-${local.bucket_suffix}-frontend"
    upload_staging = "mlm-${local.bucket_suffix}-upload-staging"
  }
}

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────
# KMS Keys (separate per sensitivity tier)
# ─────────────────────────────────────────────
resource "aws_kms_key" "artifacts" {
  description             = "MLM S3 artifacts encryption - ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags = merge(var.common_tags, { Name = "mlm-${var.environment}-kms-artifacts" })
}

resource "aws_kms_key" "audit" {
  description             = "MLM S3 audit archive encryption - ${var.environment}"
  deletion_window_in_days = 30  # Longer for audit key
  enable_key_rotation     = true
  tags = merge(var.common_tags, { Name = "mlm-${var.environment}-kms-audit" })
}

resource "aws_kms_alias" "artifacts" {
  name          = "alias/mlm-${var.environment}-s3-artifacts"
  target_key_id = aws_kms_key.artifacts.key_id
}

resource "aws_kms_alias" "audit" {
  name          = "alias/mlm-${var.environment}-s3-audit"
  target_key_id = aws_kms_key.audit.key_id
}

# ─────────────────────────────────────────────
# Reusable bucket baseline (applied to all buckets)
# ─────────────────────────────────────────────

# Block all public access on every bucket
resource "aws_s3_bucket_public_access_block" "all" {
  for_each = local.buckets

  bucket                  = aws_s3_bucket.all[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning on all buckets
resource "aws_s3_bucket_versioning" "all" {
  for_each = {
    for k, v in local.buckets : k => v
    if k != "upload_staging"  # Staging bucket: no versioning needed
  }

  bucket = aws_s3_bucket.all[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

# ─────────────────────────────────────────────
# Buckets
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "all" {
  for_each = local.buckets

  bucket        = each.value
  force_destroy = var.environment == "prod" ? false : true  # Safety: prod requires manual empty

  tags = merge(var.common_tags, {
    Name    = each.value
    Purpose = each.key
  })
}

# ─────────────────────────────────────────────
# Encryption per bucket
# ─────────────────────────────────────────────
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.all["artifacts"].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.artifacts.arn
    }
    bucket_key_enabled = true  # Reduces KMS API calls/cost
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_archive" {
  bucket = aws_s3_bucket.all["audit_archive"].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "others" {
  for_each = toset(["reports", "frontend", "upload_staging"])

  bucket = aws_s3_bucket.all[each.value].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # SSE-S3 sufficient for non-audit buckets
    }
  }
}

# ─────────────────────────────────────────────
# Lifecycle Rules
# ─────────────────────────────────────────────

# Artifacts: IA after 90d, Glacier IR after 365d; abort incomplete multipart after 2d
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.all["artifacts"].id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    abort_incomplete_multipart_upload { days_after_initiation = 2 }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 365
      storage_class = "GLACIER_IR"
    }
    noncurrent_version_expiration { noncurrent_days = 90 }
  }
}

# Upload staging: expire all objects after 2 days
resource "aws_s3_bucket_lifecycle_configuration" "upload_staging" {
  bucket = aws_s3_bucket.all["upload_staging"].id

  rule {
    id     = "expire-all-staging-objects"
    status = "Enabled"
    expiration { days = 2 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

# Reports: IA after 180d, Glacier IR after 365d
resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.all["reports"].id

  rule {
    id     = "transition-reports"
    status = "Enabled"
    transition {
      days          = 180
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 365
      storage_class = "GLACIER_IR"
    }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

# ─────────────────────────────────────────────
# Audit Archive: Object Lock (COMPLIANCE mode)
# Requires bucket created with object lock enabled
# ─────────────────────────────────────────────

# NOTE: Object Lock must be enabled at bucket creation time.
# Separate resource required — cannot be added to existing bucket.
resource "aws_s3_bucket" "audit_archive_locked" {
  # Only create the Object Lock version in prod.
  # Staging uses the standard audit_archive bucket without Object Lock.
  count = var.environment == "prod" ? 1 : 0

  bucket        = "mlm-${local.bucket_suffix}-audit-archive-locked"
  object_lock_enabled = true

  tags = merge(var.common_tags, {
    Name    = "mlm-${local.bucket_suffix}-audit-archive-locked"
    Purpose = "audit_archive_locked"
  })
}

resource "aws_s3_bucket_object_lock_configuration" "audit" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.audit_archive_locked[0].id

  rule {
    default_retention {
      mode  = "COMPLIANCE"
      years = 10
    }
  }
}

# ─────────────────────────────────────────────
# Enforce TLS on all buckets (deny HTTP)
# ─────────────────────────────────────────────
resource "aws_s3_bucket_policy" "enforce_tls" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.all[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::${each.value}",
          "arn:aws:s3:::${each.value}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.all]
}

# ─────────────────────────────────────────────
# CORS on upload-staging (for presigned POST from browser)
# ─────────────────────────────────────────────
resource "aws_s3_bucket_cors_configuration" "upload_staging" {
  bucket = aws_s3_bucket.all["upload_staging"].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = var.allowed_cors_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
