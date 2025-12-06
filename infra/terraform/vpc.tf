// VPC principal del proyecto
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

// Restrict default security group (CKV2_AWS_12)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-default-sg-restricted" }
}

// VPC Flow Logs (CKV2_AWS_11)
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${local.name_prefix}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn
  tags              = { Name = "${local.name_prefix}-vpc-flow-logs" }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Effect   = "Allow"
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  tags            = { Name = "${local.name_prefix}-vpc-flow-log" }
}

// Internet Gateway para el tráfico de salida/entrada en subredes públicas
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

// Subredes públicas (una por AZ) con IP pública automática
resource "aws_subnet" "public" {
  for_each                = { for idx, az in var.azs : idx => az }
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[tonumber(each.key)]
  availability_zone       = each.value
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name_prefix}-public-${each.value}" }
}

// Subredes privadas (una por AZ) sin exposición directa a Internet
resource "aws_subnet" "private" {
  for_each          = { for idx, az in var.azs : idx => az }
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[tonumber(each.key)]
  availability_zone = each.value
  tags              = { Name = "${local.name_prefix}-private-${each.value}" }
}

// Subredes privadas dedicadas a la base de datos (una por AZ)
resource "aws_subnet" "db" {
  for_each          = { for idx, az in var.azs : idx => az }
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnets[tonumber(each.key)]
  availability_zone = each.value
  tags              = { Name = "${local.name_prefix}-db-${each.value}" }
}

// Elastic IP para el NAT Gateway (dominio VPC)
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"
  depends_on = [
    aws_internet_gateway.igw
  ]
  tags = { Name = "${local.name_prefix}-nat-eip-${each.key}" }
}

// NAT Gateway por AZ para permitir que instancias en subredes privadas salgan a Internet
resource "aws_nat_gateway" "nat" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  depends_on    = [aws_internet_gateway.igw]
  tags          = { Name = "${local.name_prefix}-nat-${each.key}" }
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
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }
  depends_on = [aws_nat_gateway.nat]
  tags       = { Name = "${local.name_prefix}-private-rt-${each.key}" }
}

// Asociación de subredes privadas a su tabla de rutas (una tabla por AZ para respetar el AZ affinity del NAT)
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

// Asociación de subredes de base de datos a la tabla privada correspondiente
resource "aws_route_table_association" "db" {
  for_each       = aws_subnet.db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
