// VPC principal del proyecto
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${local.name_prefix}-vpc" }
}

// Internet Gateway para el tráfico de salida/entrada en subredes públicas
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

// Subredes públicas (una por AZ) con IP pública automática
resource "aws_subnet" "public" {
  for_each = { for idx, az in var.azs : idx => az }
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[tonumber(each.key)]
  availability_zone       = each.value
  map_public_ip_on_launch = true
  tags = { Name = "${local.name_prefix}-public-${each.value}" }
}

// Subredes privadas (una por AZ) sin exposición directa a Internet
resource "aws_subnet" "private" {
  for_each = { for idx, az in var.azs : idx => az }
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[tonumber(each.key)]
  availability_zone = each.value
  tags = { Name = "${local.name_prefix}-private-${each.value}" }
}

// Elastic IP para el NAT Gateway (dominio VPC)
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags       = { Name = "${local.name_prefix}-nat-eip" }
}

// NAT Gateway para permitir que instancias en subredes privadas salgan a Internet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  tags          = { Name = "${local.name_prefix}-nat" }
}

// Tabla de rutas públicas con salida a Internet por IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.name_prefix}-public-rt" }
}

// Asociación de subredes públicas a su tabla de rutas
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

// Tabla de rutas privadas con salida a Internet mediante NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${local.name_prefix}-private-rt" }
}

// Asociación de subredes privadas a su tabla de rutas
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
