// Repositorios ECR administrados externamente (Ansible/CICD)
data "aws_ecr_repository" "frontend" {
  name = "${local.name_prefix}-frontend"
}

data "aws_ecr_repository" "backend" {
  name = "${local.name_prefix}-backend"
}

output "ecr_frontend_url" { value = data.aws_ecr_repository.frontend.repository_url }
output "ecr_backend_url"  { value = data.aws_ecr_repository.backend.repository_url }
