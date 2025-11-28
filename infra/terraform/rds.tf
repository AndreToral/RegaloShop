// Aurora PostgreSQL con réplica en AZ secundaria
resource "random_password" "db_master" {
  length           = 20
  special          = true
  override_special = "!@$%^*-_+=?"
}

resource "aws_db_subnet_group" "aurora" {
  name       = "${local.name_prefix}-aurora-subnets"
  subnet_ids = [for s in aws_subnet.db : s.id]
  tags       = { Name = "${local.name_prefix}-aurora-subnets" }
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${local.name_prefix}-aurora"
  engine                  = "aurora-postgresql"
  engine_version          = var.db_engine_version
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = random_password.db_master.result
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  backup_retention_period = var.db_backup_retention
  preferred_backup_window = "05:00-06:00"
  storage_encrypted       = true
  deletion_protection     = false
  skip_final_snapshot     = true
  availability_zones      = var.azs
  port                    = 5432
  apply_immediately       = true

  tags = { Name = "${local.name_prefix}-aurora" }
}

resource "aws_rds_cluster_instance" "aurora_writer" {
  identifier                 = "${local.name_prefix}-aurora-writer"
  cluster_identifier         = aws_rds_cluster.aurora.id
  instance_class             = var.db_instance_class
  engine                     = aws_rds_cluster.aurora.engine
  engine_version             = aws_rds_cluster.aurora.engine_version
  availability_zone          = var.azs[0]
  publicly_accessible        = false
  promotion_tier             = 1
  auto_minor_version_upgrade = true
}

resource "aws_rds_cluster_instance" "aurora_reader" {
  identifier                 = "${local.name_prefix}-aurora-replica"
  cluster_identifier         = aws_rds_cluster.aurora.id
  instance_class             = var.db_instance_class
  engine                     = aws_rds_cluster.aurora.engine
  engine_version             = aws_rds_cluster.aurora.engine_version
  availability_zone          = var.azs[1]
  publicly_accessible        = false
  promotion_tier             = 2
  auto_minor_version_upgrade = true
}

// Secrets de DB (credenciales y conexión)
locals {
  db_connection_uri = "postgresql://${var.db_username}:${random_password.db_master.result}@${aws_rds_cluster.aurora.endpoint}:${aws_rds_cluster.aurora.port}/${var.db_name}"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.name_prefix}-aurora-credentials"
  description = "Credenciales para Aurora ${local.name_prefix}"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({ username = var.db_username, password = random_password.db_master.result, db_name = var.db_name })
}

resource "aws_secretsmanager_secret" "db_url" {
  name        = "${local.name_prefix}-aurora-url"
  description = "URL de conexión para Aurora ${local.name_prefix}"
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = local.db_connection_uri
  depends_on    = [aws_rds_cluster.aurora]
}
