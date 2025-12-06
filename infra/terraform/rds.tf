// Aurora PostgreSQL con réplica en AZ secundaria
resource "random_password" "db_master" {
  length            = 20
  special           = true
  override_special  = "!#$%&*+,-:=?^_~"
  min_special       = 2
  min_numeric       = 2
  min_upper         = 2
  min_lower         = 2
}

resource "aws_db_subnet_group" "aurora" {
  name       = "${local.name_prefix}-aurora-subnets"
  subnet_ids = [for s in aws_subnet.db : s.id]
  tags       = { Name = "${local.name_prefix}-aurora-subnets" }
}

// KMS key para encriptacion de Aurora
resource "aws_kms_key" "aurora" {
  description             = "KMS key for Aurora RDS encryption"
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
        Sid    = "Allow RDS Service"
        Effect = "Allow"
        Principal = { Service = "rds.amazonaws.com" }
        Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${local.name_prefix}-aurora-kms" }
}

// IAM role para RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier                  = "${local.name_prefix}-aurora"
  engine                              = "aurora-postgresql"
  engine_version                      = var.db_engine_version
  database_name                       = var.db_name
  master_username                     = var.db_username
  master_password                     = random_password.db_master.result
  db_subnet_group_name                = aws_db_subnet_group.aurora.name
  vpc_security_group_ids              = [aws_security_group.db.id]
  backup_retention_period             = var.db_backup_retention
  preferred_backup_window             = "05:00-06:00"
  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.aurora.arn
  iam_database_authentication_enabled = true
  deletion_protection                 = false
  skip_final_snapshot                 = true
  availability_zones                  = var.azs
  port                                = 5432
  apply_immediately                   = true
  copy_tags_to_snapshot               = true
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.aurora.name

  tags = { Name = "${local.name_prefix}-aurora" }
}

// RDS Cluster Parameter Group para Query Logging (CKV2_AWS_27)
resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${local.name_prefix}-aurora-params"
  family      = "aurora-postgresql15"
  description = "Aurora PostgreSQL parameter group with query logging"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = { Name = "${local.name_prefix}-aurora-params" }
}

resource "aws_rds_cluster_instance" "aurora_writer" {
  identifier                            = "${local.name_prefix}-aurora-writer"
  cluster_identifier                    = aws_rds_cluster.aurora.id
  instance_class                        = var.db_instance_class
  engine                                = aws_rds_cluster.aurora.engine
  engine_version                        = aws_rds_cluster.aurora.engine_version
  availability_zone                     = var.azs[0]
  publicly_accessible                   = false
  promotion_tier                        = 1
  auto_minor_version_upgrade            = true
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.aurora.arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
}

resource "aws_rds_cluster_instance" "aurora_reader" {
  identifier                            = "${local.name_prefix}-aurora-replica"
  cluster_identifier                    = aws_rds_cluster.aurora.id
  instance_class                        = var.db_instance_class
  engine                                = aws_rds_cluster.aurora.engine
  engine_version                        = aws_rds_cluster.aurora.engine_version
  availability_zone                     = var.azs[1]
  publicly_accessible                   = false
  promotion_tier                        = 2
  auto_minor_version_upgrade            = true
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.aurora.arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
}

// Secrets de DB (credenciales y conexion)
locals {
  db_connection_uri = "postgresql://${var.db_username}:${urlencode(random_password.db_master.result)}@${aws_rds_cluster.aurora.endpoint}:${aws_rds_cluster.aurora.port}/${var.db_name}"
}

// KMS key para Secrets Manager
resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
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
        Sid    = "Allow Secrets Manager"
        Effect = "Allow"
        Principal = { Service = "secretsmanager.amazonaws.com" }
        Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${local.name_prefix}-secrets-kms" }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.name_prefix}-aurora-credentials"
  description             = "Credenciales para Aurora ${local.name_prefix}"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({ username = var.db_username, password = random_password.db_master.result, db_name = var.db_name })
}

resource "aws_secretsmanager_secret" "db_url" {
  name                    = "${local.name_prefix}-aurora-url"
  description             = "URL de conexion para Aurora ${local.name_prefix}"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = local.db_connection_uri
  depends_on    = [aws_rds_cluster.aurora]
}
