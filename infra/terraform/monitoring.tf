// CloudWatch Dashboard - Peticiones por Minuto

resource "aws_cloudwatch_dashboard" "main" {
  count          = var.enable_edge ? 1 : 0
  dashboard_name = "${local.name_prefix}-usuarios-activos"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 8
        properties = {
          title  = "Peticiones por Minuto"
          region = var.region
          stat   = "Sum"
          period = 60
          view   = "singleValue"
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.edge[0].id, "Region", "Global", { label = "Requests/min" }]
          ]
        }
      }
    ]
  })
}

// Output para acceder al dashboard
output "cloudwatch_dashboard_url" {
  description = "URL del dashboard de CloudWatch"
  value       = var.enable_edge ? "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : ""
}
