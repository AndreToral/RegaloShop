// DNS público del Application Load Balancer
output "alb_url" {
  value       = aws_lb.public.dns_name
  description = "Public ALB DNS"
}

// Nombre del cluster ECS creado
output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}
