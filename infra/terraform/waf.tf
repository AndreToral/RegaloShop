// WAF asociado a CloudFront
resource "aws_wafv2_web_acl" "main" {
  count       = var.enable_edge ? 1 : 0
  name        = "${local.name_prefix}-waf"
  description = "Basic protection for CloudFront - monitoring mode"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-waf-badinputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }
}

// WAF Logging (CKV2_AWS_31)
resource "aws_cloudwatch_log_group" "waf" {
  count             = var.enable_edge ? 1 : 0
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn
  tags              = { Name = "${local.name_prefix}-waf-logs" }
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count                   = var.enable_edge ? 1 : 0
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.main[0].arn

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}