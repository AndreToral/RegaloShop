locals {
  apigw_domain = var.enable_edge ? replace(aws_apigatewayv2_api.edge[0].api_endpoint, "https://", "") : null
}

resource "aws_cloudfront_distribution" "edge" {
  count               = var.enable_edge ? 1 : 0
  enabled             = true
  comment             = "${local.name_prefix}-cdn"
  aliases             = [var.zone_name]
  default_root_object = ""

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

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies { forward = "all" }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.cloudfront_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.main[0].arn

  price_class = "PriceClass_100"

  tags = { Name = "${local.name_prefix}-cdn" }
}
