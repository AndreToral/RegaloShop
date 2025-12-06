locals {
  apigw_domain = var.enable_edge ? replace(aws_apigatewayv2_api.edge[0].api_endpoint, "https://", "") : null
}

// S3 Bucket for CloudFront Access Logs
resource "aws_s3_bucket" "cloudfront_logs" {
  count         = var.enable_edge ? 1 : 0
  bucket        = "${local.name_prefix}-cf-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true  # Permite eliminar bucket con objetos en terraform destroy

  tags = { Name = "${local.name_prefix}-cf-logs" }
}

resource "aws_s3_bucket_versioning" "cloudfront_logs" {
  count  = var.enable_edge ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  count  = var.enable_edge ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  count  = var.enable_edge ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  count  = var.enable_edge ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  count  = var.enable_edge ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  count  = var.enable_edge ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
}

// Response Headers Policy para seguridad (CKV2_AWS_32)
resource "aws_cloudfront_response_headers_policy" "security" {
  count   = var.enable_edge ? 1 : 0
  name    = "${local.name_prefix}-security-headers"
  comment = "Security headers policy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    content_type_options {
      override = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
    referrer_policy {
      override        = true
      referrer_policy = "strict-origin-when-cross-origin"
    }
  }
}

resource "aws_cloudfront_distribution" "edge" {
  count               = var.enable_edge ? 1 : 0
  enabled             = true
  comment             = "${local.name_prefix}-cdn"
  aliases             = [var.zone_name]
  default_root_object = ""
  web_acl_id          = aws_wafv2_web_acl.main[0].arn

  # Single origin: API Gateway (que a su vez usa VPC Link para acceder al ALB privado)
  origin {
    domain_name = local.apigw_domain
    origin_id   = "api-gateway"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior: Todo pasa a través de API Gateway
  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "api-gateway"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security[0].id

    forwarded_values {
      query_string = true
      headers      = ["Accept", "Accept-Language", "Content-Type", "Authorization", "Origin", "Referer"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs[0].bucket_domain_name
    prefix          = "cf-logs/"
  }

  viewer_certificate {
    acm_certificate_arn      = var.cloudfront_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  price_class = "PriceClass_100"

  tags = { Name = "${local.name_prefix}-cdn" }
}
