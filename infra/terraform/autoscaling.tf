// Escalado automático para servicios ECS (Fargate) en ambos clusters

locals {
  frontend_resource_labels = { for k, tg in aws_lb_target_group.frontend : k => "${aws_lb.private.arn_suffix}/${tg.arn_suffix}" }
  backend_resource_labels  = { for k, tg in aws_lb_target_group.backend : k => "${aws_lb.private.arn_suffix}/${tg.arn_suffix}" }
}

// Frontend - Target para DesiredCount
resource "aws_appautoscaling_target" "frontend" {
  for_each           = aws_ecs_service.frontend
  max_capacity       = var.frontend_max_count
  min_capacity       = var.frontend_min_count
  resource_id        = "service/${aws_ecs_cluster.az[each.key].name}/${each.value.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

// Frontend - Escalado por CPU promedio del servicio
resource "aws_appautoscaling_policy" "frontend_cpu" {
  for_each           = aws_appautoscaling_target.frontend
  name               = "${local.name_prefix}-frontend-cpu-tt-${each.key}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.frontend_cpu_target
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

// Frontend - Escalado por requests en el ALB
resource "aws_appautoscaling_policy" "frontend_requests" {
  for_each           = aws_appautoscaling_target.frontend
  name               = "${local.name_prefix}-frontend-req-tt-${each.key}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.frontend_requests_per_target
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = local.frontend_resource_labels[each.key]
    }
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

// Backend - Target para DesiredCount
resource "aws_appautoscaling_target" "backend" {
  for_each           = aws_ecs_service.backend
  max_capacity       = var.backend_max_count
  min_capacity       = var.backend_min_count
  resource_id        = "service/${aws_ecs_cluster.az[each.key].name}/${each.value.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

// Backend - Escalado por CPU promedio del servicio
resource "aws_appautoscaling_policy" "backend_cpu" {
  for_each           = aws_appautoscaling_target.backend
  name               = "${local.name_prefix}-backend-cpu-tt-${each.key}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.backend_cpu_target
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

// Backend - Escalado por requests en el ALB
resource "aws_appautoscaling_policy" "backend_requests" {
  for_each           = aws_appautoscaling_target.backend
  name               = "${local.name_prefix}-backend-req-tt-${each.key}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.backend_requests_per_target
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = local.backend_resource_labels[each.key]
    }
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}
