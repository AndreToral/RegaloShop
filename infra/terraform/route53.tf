// Usar zona Route 53 existente (creada manualmente)
// En lugar de crear una nueva, referenciamos la que ya existe
data "aws_route53_zone" "main" {
  count = var.enable_edge ? 1 : 0
  name  = var.zone_name
}

// Registro A que apunta CloudFront a la zona existente
resource "aws_route53_record" "cdn" {
  count   = var.enable_edge ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.zone_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.edge[0].domain_name
    zone_id                = aws_cloudfront_distribution.edge[0].hosted_zone_id
    evaluate_target_health = false
  }
}
