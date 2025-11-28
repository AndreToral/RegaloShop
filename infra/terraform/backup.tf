// Backup plan específico para la réplica de Aurora
data "aws_iam_policy" "backup_service" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role" "backup" {
  name = "${local.name_prefix}-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "backup.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = data.aws_iam_policy.backup_service.arn
}

resource "aws_backup_vault" "main" {
  name = "${local.name_prefix}-backup-vault"
  tags = { Name = "${local.name_prefix}-backup-vault" }
}

resource "aws_backup_plan" "aurora_replica" {
  name = "${local.name_prefix}-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 * * ? *)"
    lifecycle {
      delete_after = 30
    }
  }
}

resource "aws_backup_selection" "aurora_replica" {
  name         = "${local.name_prefix}-aurora-replica-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.aurora_replica.id
  resources    = [aws_rds_cluster_instance.aurora_reader.arn]
}
