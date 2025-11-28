// DNS interno del Application Load Balancer (para VPC Link)
output "alb_dns_name" {
  value       = aws_lb.private.dns_name
  description = "Internal ALB DNS"
}

// Nombres de los clusters ECS (uno por AZ)
output "ecs_cluster_names" {
  value       = [for c in aws_ecs_cluster.az : c.name]
  description = "ECS clusters per AZ"
}

output "cloudfront_domain_name" {
  value       = var.enable_edge && length(aws_cloudfront_distribution.edge) > 0 ? aws_cloudfront_distribution.edge[0].domain_name : null
  description = "CloudFront distribution domain (null si edge deshabilitado)"
}

output "route53_zone_id" {
  value       = var.enable_edge && length(aws_route53_zone.main) > 0 ? aws_route53_zone.main[0].zone_id : null
  description = "Hosted zone ID (null si edge deshabilitado)"
}

output "api_gateway_endpoint" {
  value       = var.enable_edge && length(aws_apigatewayv2_api.edge) > 0 ? aws_apigatewayv2_api.edge[0].api_endpoint : null
  description = "API Gateway invoke URL (null si edge deshabilitado)"
}

output "aurora_cluster_endpoint" {
  value       = aws_rds_cluster.aurora.endpoint
  description = "Writer endpoint"
}

output "aurora_reader_endpoint" {
  value       = aws_rds_cluster.aurora.reader_endpoint
  description = "Reader endpoint"
}

output "db_secret_arn" {
  value       = aws_secretsmanager_secret.db_url.arn
  description = "Secret ARN for DATABASE_URL"
}
