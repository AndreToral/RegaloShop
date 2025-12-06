// API Gateway HTTP que enruta al ALB privado mediante VPC Link
resource "aws_apigatewayv2_api" "edge" {
  count         = var.enable_edge ? 1 : 0
  name          = "${local.name_prefix}-apigw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_vpc_link" "edge" {
  count              = var.enable_edge ? 1 : 0
  name               = "${local.name_prefix}-vpclink"
  security_group_ids = [aws_security_group.apigw_vpc_link[0].id]
  subnet_ids         = [for s in aws_subnet.private : s.id]
}

resource "aws_apigatewayv2_integration" "alb" {
  count                  = var.enable_edge ? 1 : 0
  api_id                 = aws_apigatewayv2_api.edge[0].id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.edge[0].id
  integration_uri        = aws_lb_listener.http.arn
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_route" "root" {
  count     = var.enable_edge ? 1 : 0
  api_id    = aws_apigatewayv2_api.edge[0].id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.alb[0].id}"
}

resource "aws_apigatewayv2_route" "proxy" {
  count     = var.enable_edge ? 1 : 0
  api_id    = aws_apigatewayv2_api.edge[0].id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb[0].id}"
}

// CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "apigw" {
  count             = var.enable_edge ? 1 : 0
  name              = "/aws/apigateway/${local.name_prefix}-apigw"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn

  tags = { Name = "${local.name_prefix}-apigw-logs" }
}

resource "aws_apigatewayv2_stage" "default" {
  count       = var.enable_edge ? 1 : 0
  api_id      = aws_apigatewayv2_api.edge[0].id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw[0].arn
    format = jsonencode({
      requestId         = "$context.requestId"
      ip                = "$context.identity.sourceIp"
      requestTime       = "$context.requestTime"
      httpMethod        = "$context.httpMethod"
      routeKey          = "$context.routeKey"
      status            = "$context.status"
      protocol          = "$context.protocol"
      responseLength    = "$context.responseLength"
      integrationError  = "$context.integrationErrorMessage"
      integrationStatus = "$context.integrationStatus"
    })
  }

  default_route_settings {
    throttling_burst_limit = 300
    throttling_rate_limit  = 200
  }
}
