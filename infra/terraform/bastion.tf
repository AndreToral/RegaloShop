// Host utilitario SSM para ejecutar tareas dentro de la VPC (p. ej. aurora-load)
data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-arm64*"]
  }
}

resource "aws_iam_role" "utility" {
  name               = "${local.name_prefix}-utility-role"
  assume_role_policy = data.aws_iam_policy_document.utility_assume.json
}

data "aws_iam_policy_document" "utility_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "utility_ssm" {
  role       = aws_iam_role.utility.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "utility" {
  name = "${local.name_prefix}-utility-profile"
  role = aws_iam_role.utility.name
}

resource "aws_instance" "utility" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.utility.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.utility.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker git nodejs
              systemctl enable docker
              systemctl start docker
              EOF

  tags = {
    Name = "${local.name_prefix}-utility"
  }
}

output "utility_instance_id" {
  value       = aws_instance.utility.id
  description = "ID del host utilitario SSM"
}

output "utility_public_ip" {
  value       = aws_instance.utility.public_ip
  description = "IP pública del host utilitario (solo para SSM/gestión, no expone servicios)."
}
