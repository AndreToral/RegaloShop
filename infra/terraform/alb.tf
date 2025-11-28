// Application Load Balancer público (expuesto mientras se deshabilita el edge)
resource "aws_lb" "private" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = { Name = "${local.name_prefix}-alb" }
}

// Target Groups por AZ para frontend y backend
resource "aws_lb_target_group" "frontend" {
  for_each    = local.ecs_clusters
  name        = "${local.name_prefix}-tg-frontend-${each.value.az}"
  port        = var.frontend_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}

resource "aws_lb_target_group" "backend" {
  for_each    = local.ecs_clusters
  name        = "${local.name_prefix}-tg-backend-${each.value.az}"
  port        = var.backend_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-499"
  }
}

// Listener HTTP. Por defecto envía tráfico al frontend
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.private.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "forward"
    forward {
      dynamic "target_group" {
        for_each = aws_lb_target_group.frontend
        content {
          arn    = target_group.value.arn
          weight = 1
        }
      }
    }
  }
}

// Regla que enruta /api* hacia el backend
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type = "forward"
    forward {
      dynamic "target_group" {
        for_each = aws_lb_target_group.backend
        content {
          arn    = target_group.value.arn
          weight = 1
        }
      }
    }
  }
  condition {
    path_pattern { values = ["/api*", "/api/*"] }
  }
}
