
// Bastion Host EC2 para ejecutar migraciones de BD


// EC2 Key Pair para Bastion (importar clave pública existente)
resource "aws_key_pair" "bastion" {
  key_name   = "${local.name_prefix}-bastion-key"
  public_key = file("${path.module}/bastion_public_key.pub")
  
  tags = {
    Name = "${local.name_prefix}-bastion-key"
  }
}

// Security Group para Bastion
resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Security group for Bastion Host - allows SSH access for database migrations and maintenance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  // ⚠️  En prod, restringir a IPs específicas
    description = "SSH from anywhere - restrict in production"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS APIs and package downloads"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound for package downloads"
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL to Aurora within VPC"
  }

  tags = { Name = "${local.name_prefix}-bastion-sg" }
}

// Security Group Ingress para que Bastion acceda a Aurora
resource "aws_security_group_rule" "bastion_to_aurora" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.db.id
  description              = "Bastion to Aurora"
}

// IAM Role para Bastion EC2
resource "aws_iam_role" "bastion" {
  name = "${local.name_prefix}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

// Policy para acceder a Secrets Manager
resource "aws_iam_role_policy" "bastion_secrets" {
  name = "${local.name_prefix}-bastion-secrets"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_url.arn,
          aws_secretsmanager_secret.db_credentials.arn
        ]
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          aws_kms_key.secrets.arn
        ]
      }
    ]
  })
}

// Instance Profile para Bastion
resource "aws_iam_instance_profile" "bastion" {
  name = "${local.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion.name
}

// User Data Script para Bastion
locals {
  bastion_public_key = file("${path.module}/bastion_public_key.pub")
  bastion_user_data = base64encode(templatefile("${path.module}/bastion-init.sh", {
    project_name       = local.name_prefix
    region             = var.region
    bastion_public_key = local.bastion_public_key
  }))
}

// EC2 Instance para Bastion
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"  // Free tier eligible
  subnet_id              = aws_subnet.public[0].id
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name               = aws_key_pair.bastion.key_name
  user_data_base64       = local.bastion_user_data
  ebs_optimized          = true
  monitoring             = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name = "${local.name_prefix}-bastion"
  }

  depends_on = [
    aws_security_group_rule.bastion_to_aurora
  ]
}

// Data source para obtener la AMI más reciente de Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  // Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

// Outputs
output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "IP pública del Bastion Host"
}

output "bastion_instance_id" {
  value       = aws_instance.bastion.id
  description = "ID de la instancia Bastion"
}
