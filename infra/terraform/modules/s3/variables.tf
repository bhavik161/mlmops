# infra/terraform/modules/s3/variables.tf

variable "project"     { type = string; default = "mlm" }
variable "environment" { type = string }
variable "common_tags" { type = map(string); default = {} }

variable "allowed_cors_origins" {
  type        = list(string)
  description = "Allowed CORS origins for upload-staging bucket (your app domain)"
  default     = ["https://*.mlm.yourdomain.com"]
}


# infra/terraform/modules/s3/outputs.tf

output "artifacts_bucket" {
  value = aws_s3_bucket.all["artifacts"].id
}

output "reports_bucket" {
  value = aws_s3_bucket.all["reports"].id
}

output "audit_archive_bucket" {
  value = aws_s3_bucket.all["audit_archive"].id
}

output "frontend_bucket" {
  value = aws_s3_bucket.all["frontend"].id
}

output "upload_staging_bucket" {
  value = aws_s3_bucket.all["upload_staging"].id
}

output "artifacts_bucket_arn" {
  value = aws_s3_bucket.all["artifacts"].arn
}

output "audit_kms_key_arn" {
  value = aws_kms_key.audit.arn
}

output "artifacts_kms_key_arn" {
  value = aws_kms_key.artifacts.arn
}
