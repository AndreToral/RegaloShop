resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow HTTP from CloudFront and VPC Link"
  vpc_id      = aws_vpc.main.id

  # Acceso desde CloudFront (ranges de IPs de CloudFront)
  ingress {
    description = "HTTP from CloudFront"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      "18.160.0.0/13",      # CloudFront edge locations
      "99.86.0.0/16",       # CloudFront additional ranges
      "34.64.0.0/10",       # CloudFront additional ranges
      "34.128.0.0/10",      # CloudFront additional ranges
      "52.0.0.0/8",         # CloudFront ranges
      "54.0.0.0/8",         # CloudFront ranges
    ]
  }

  # Acceso desde VPC Link (API Gateway para /api/*)
  ingress {
    description     = "HTTP from VPC Link (API Gateway)"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = var.enable_edge ? [aws_security_group.apigw_vpc_link[0].id] : []
  }

  tags = { Name = "${local.name_prefix}-alb-sg" }
}

# Egress rules for ALB (separate to avoid cycle)
resource "aws_security_group_rule" "alb_to_ecs_frontend" {
  type                     = "egress"
  from_port                = var.frontend_container_port
  to_port                  = var.frontend_container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "To ECS frontend tasks"
}

resource "aws_security_group_rule" "alb_to_ecs_backend" {
  type                     = "egress"
  from_port                = var.backend_container_port
  to_port                  = var.backend_container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "To ECS backend tasks"
}

// SG para el VPC Link del API Gateway (solo si enable_edge)
resource "aws_security_group" "apigw_vpc_link" {
  count       = var.enable_edge ? 1 : 0
  name        = "${local.name_prefix}-apigw-vpclink-sg"
  description = "VPC Link connecting to private ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Self reference for VPC Link internal communication"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "HTTP to private ALB within VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = { Name = "${local.name_prefix}-apigw-vpclink-sg" }
}

// SG de tareas ECS: solo acepta trafico desde el ALB hacia los puertos expuestos
resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Allow traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Frontend from ALB"
    from_port       = var.frontend_container_port
    to_port         = var.frontend_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Backend from ALB"
    from_port       = var.backend_container_port
    to_port         = var.backend_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS to AWS APIs (ECR, CloudWatch, Secrets Manager)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-ecs-tasks-sg" }
}

# Egress rule for ECS tasks to DB (separate to avoid cycle)
resource "aws_security_group_rule" "ecs_to_db" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.db.id
  description              = "PostgreSQL to Aurora"
}

// SG para Aurora: permite acceso desde las tareas ECS
resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "Permite acceso Postgres desde ECS"
  vpc_id      = aws_vpc.main.id

  # Acceso desde host utilitario (bastion/SSM) para tareas de carga/mantenimiento
  ingress {
    description     = "PostgreSQL from utility host"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.utility.id]
  }

  # Aurora no necesita egress, las conexiones son entrantes
  tags = { Name = "${local.name_prefix}-db-sg" }
}

# Ingress rule for DB from ECS (separate to avoid cycle)
resource "aws_security_group_rule" "db_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "PostgreSQL from ECS tasks"
}

# SG para host utilitario (para correr seeds/migraciones dentro de la VPC)
resource "aws_security_group" "utility" {
  name        = "${local.name_prefix}-utility-sg"
  description = "Host utilitario para tareas administrativas"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS to AWS APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "PostgreSQL to Aurora within VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${local.name_prefix}-utility-sg" }
}
