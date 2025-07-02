data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# ==========================================================
#                  S3 Bucket Configuration
# ==========================================================

resource "aws_s3_bucket" "proxy_config" {
  bucket = "${var.stack_name}-app-proxy-config-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = true # same as `autoDeleteObjects: true` + destroy policy

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-app-proxy-config-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
    }
  )
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "proxy_config" {
  bucket = aws_s3_bucket.proxy_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "proxy_config" {
  bucket = aws_s3_bucket.proxy_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # same as `S3_MANAGED`
    }
  }
}

