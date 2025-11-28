// Variables de entrada para parametrizar el despliegue
// Nombre corto del proyecto para prefijar recursos
variable "project_name" {
  type = string
}

// Región AWS donde se desplegará la infraestructura
variable "region" {
  type = string
}

// CIDR principal de la VPC
variable "vpc_cidr" {
  type = string
}

// Zonas de disponibilidad a utilizar
variable "azs" {
  type = list(string)
}

// Subredes públicas (una por AZ)
variable "public_subnets" {
  type = list(string)
}

// Subredes privadas (una por AZ)
variable "private_subnets" {
  type = list(string)
}

// Subredes privadas dedicadas para la base de datos (una por AZ)
variable "db_subnets" {
  type = list(string)
}

// Tags de imagen OCI (ECR) a desplegar en ECS
variable "frontend_image_tag" {
  type = string
}

variable "backend_image_tag" {
  type = string
}

// Puertos de los contenedores
variable "frontend_container_port" {
  type    = number
  default = 80
}

variable "backend_container_port" {
  type    = number
  default = 4000
}

// Escalabilidad - mínimos y máximos de réplicas (ECS DesiredCount)
variable "frontend_min_count" {
  type = number
}

variable "frontend_max_count" {
  type = number
}

variable "backend_min_count" {
  type = number
}

variable "backend_max_count" {
  type = number
}

// Objetivos de escalado (Target Tracking)
variable "frontend_cpu_target" {
  type    = number
  default = 60
}

variable "backend_cpu_target" {
  type    = number
  default = 60
}

// Requests por target en ALB para escalar por tráfico
variable "frontend_requests_per_target" {
  type    = number
  default = 100
}

variable "backend_requests_per_target" {
  type    = number
  default = 60
}

// Cooldowns de escalado (segundos)
variable "scale_in_cooldown" {
  type    = number
  default = 120
}

variable "scale_out_cooldown" {
  type    = number
  default = 60
}

// Habilita capa de borde (Route53 + CloudFront + WAF + API Gateway)
variable "enable_edge" {
  type    = bool
  default = false
}

// Dominio y certificados
variable "zone_name" {
  type = string
}

variable "cloudfront_certificate_arn" {
  type = string
}

// Base de datos Aurora
variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_engine_version" {
  type    = string
  default = "15.8"
}

variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "db_backup_retention" {
  type    = number
  default = 7
}
