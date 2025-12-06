// Clusters ECS (uno por AZ) para aislar servicios por zona
locals {
  ecs_clusters = {
    a = {
      az        = var.azs[0]
      subnet_id = aws_subnet.private["0"].id
      name      = "${local.name_prefix}-cluster-${var.azs[0]}"
    }
    b = {
      az        = var.azs[1]
      subnet_id = aws_subnet.private["1"].id
      name      = "${local.name_prefix}-cluster-${var.azs[1]}"
    }
  }
}

resource "aws_ecs_cluster" "az" {
  for_each = local.ecs_clusters
  name     = each.value.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

// KMS key para CloudWatch Logs
resource "aws_kms_key" "logs" {
  description             = "KMS key for CloudWatch Logs encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = { Name = "${local.name_prefix}-logs-kms" }
}

data "aws_caller_identity" "current" {}

// Logs de CloudWatch para el frontend
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${local.name_prefix}-frontend"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn
}

// Logs de CloudWatch para el backend
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.name_prefix}-backend"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn
}

locals {
  frontend_image = "${data.aws_ecr_repository.frontend.repository_url}:${var.frontend_image_tag}"
  backend_image  = "${data.aws_ecr_repository.backend.repository_url}:${var.backend_image_tag}"
}

// Definición de tarea Fargate para el frontend
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${local.name_prefix}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name         = "frontend"
      image        = local.frontend_image
      essential    = true
      portMappings = [{ containerPort = var.frontend_container_port, hostPort = var.frontend_container_port, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.frontend.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "NODE_ENV", value = "production" }
      ]
    }
  ])
}

// Definición de tarea Fargate para el backend
resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name_prefix}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name         = "backend"
      image        = local.backend_image
      essential    = true
      portMappings = [{ containerPort = var.backend_container_port, hostPort = var.backend_container_port, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "PORT", value = tostring(var.backend_container_port) },
        { name = "DISABLE_DB_HEALTHCHECK", value = "false" }
      ]
      secrets = [
        { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.db_url.arn }
      ]
    }
  ])
}

// Servicio ECS para el frontend (un servicio por AZ)
resource "aws_ecs_service" "frontend" {
  for_each                          = local.ecs_clusters
  name                              = "${local.name_prefix}-frontend-${each.value.az}"
  cluster                           = aws_ecs_cluster.az[each.key].id
  task_definition                   = aws_ecs_task_definition.frontend.arn
  desired_count                     = var.frontend_min_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 110
  deployment_minimum_healthy_percent = 50

  network_configuration {
    subnets          = [each.value.subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend[each.key].arn
    container_name   = "frontend"
    container_port   = var.frontend_container_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group.frontend,
  ]

  lifecycle { ignore_changes = [task_definition, desired_count] }
}

// Servicio ECS para el backend (un servicio por AZ)
resource "aws_ecs_service" "backend" {
  for_each                          = local.ecs_clusters
  name                              = "${local.name_prefix}-backend-${each.value.az}"
  cluster                           = aws_ecs_cluster.az[each.key].id
  task_definition                   = aws_ecs_task_definition.backend.arn
  desired_count                     = var.backend_min_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 110
  deployment_minimum_healthy_percent = 50

  network_configuration {
    subnets          = [each.value.subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend[each.key].arn
    container_name   = "backend"
    container_port   = var.backend_container_port
  }

  depends_on = [
    aws_lb_listener_rule.api,
    aws_lb_target_group.backend,
  ]

  lifecycle { ignore_changes = [task_definition, desired_count] }
}
