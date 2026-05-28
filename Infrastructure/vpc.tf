# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "three-tier-vpc" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

# Public Subnets (External ALB)
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags              = { Name = "public-1a" }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags              = { Name = "public-1b" }
}

# NAT Gateway for Private Subnets
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id
  tags          = { Name = "nat-gateway" }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "private-rt" }
}

# Route Table Associations
resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Web Private Subnets
resource "aws_subnet" "web_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "web-private-1a" }
}

resource "aws_subnet" "web_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "web-private-1b" }
}

# App Private Subnets
resource "aws_subnet" "app_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "app-private-1a" }
}

resource "aws_subnet" "app_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "app-private-1b" }
}

# Database Private Subnets
resource "aws_subnet" "db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "db-private-1a" }
}

resource "aws_subnet" "db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.31.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "db-private-1b" }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "web_1" {
  subnet_id      = aws_subnet.web_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "web_2" {
  subnet_id      = aws_subnet.web_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_1" {
  subnet_id      = aws_subnet.app_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_2" {
  subnet_id      = aws_subnet.app_2.id
  route_table_id = aws_route_table.private.id
}