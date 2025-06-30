# ==========================================================
#                    S3 Bucker for SDK
# ==========================================================

resource "aws_s3_bucket" "hyperswitch_sdk" {
  bucket = "${var.stack_name}-sdk-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-waf-logs"
    }
  )
}

resource "aws_s3_bucket_acl" "hyperswitch_sdk" {
  bucket = aws_s3_bucket.hyperswitch_sdk.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "hyperswitch_sdk" {
  bucket = aws_s3_bucket.hyperswitch_sdk.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "hyperswitch_sdk" {
  bucket = aws_s3_bucket.hyperswitch_sdk.id

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }

}

# ==========================================================
#              Cloudfront Configuration for SDK
# ==========================================================

resource "aws_cloudfront_origin_access_identity" "sdk_oai" {
  comment = "OAI for Hyperswitch SDK bucket"
}

resource "aws_s3_bucket_policy" "sdk_bucket_policy" {
  bucket = aws_s3_bucket.hyperswitch_sdk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.sdk_oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.hyperswitch_sdk.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.hyperswitch_sdk]
}

# ==========================================================
#              Cloudfront Distribution for SDK
# ==========================================================

resource "aws_cloudfront_distribution" "sdk_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Hyperswitch SDK Distribution"
  default_root_object = "index.html"

  # Origin configuration for S3
  origin {
    domain_name = aws_s3_bucket.hyperswitch_sdk.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.hyperswitch_sdk.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.sdk_oai.cloudfront_access_identity_path
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.hyperswitch_sdk.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Additional cache behavior for /* pattern
  ordered_cache_behavior {
    path_pattern     = "/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.hyperswitch_sdk.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Price class
  price_class = "PriceClass_All"

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Viewer certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "sdkDistribution"
  }

  depends_on = [aws_s3_bucket.hyperswitch_sdk]
}
