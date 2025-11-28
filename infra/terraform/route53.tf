// Zona hospedada pública y registro apuntando al CloudFront
resource "aws_route53_zone" "main" {
  count = var.enable_edge ? 1 : 0
  name  = var.zone_name
  tags  = { Name = "${local.name_prefix}-zone" }
}

resource "aws_route53_record" "cdn" {
  count   = var.enable_edge ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.zone_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.edge[0].domain_name
    zone_id                = aws_cloudfront_distribution.edge[0].hosted_zone_id
    evaluate_target_health = false
  }
}
