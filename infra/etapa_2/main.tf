terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

############################
# VPC y subredes
############################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = { Name = "${var.project_name}-private" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

############################
# Security Groups
############################

resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg"
  description = "Solo frontend accesible desde Internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Backends solo desde frontend (subred privada)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "API ventas desde frontend"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description     = "API despachos desde frontend"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description     = "SSH desde frontend (bastion para CI/CD)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mysql" {
  name        = "${var.project_name}-mysql-sg"
  description = "MySQL solo desde backends"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL desde backends"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# ECR (creados en etapa_1)
############################

data "aws_ecr_repository" "backend_ventas" {
  name = "${var.project_name}-backend-ventas"
}

data "aws_ecr_repository" "backend_despachos" {
  name = "${var.project_name}-backend-despachos"
}

data "aws_ecr_repository" "frontend" {
  name = "${var.project_name}-frontend"
}

data "aws_caller_identity" "current" {}

locals {
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

############################
# IAM para EC2 (pull ECR)
############################

data "aws_iam_role" "lab" {
  name = "LabRole"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = data.aws_iam_role.lab.name
}

############################
# AMI
############################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

############################
# EC2 MySQL (subred privada + volumen Docker)
############################

resource "aws_instance" "db" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.mysql.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/templates/mysql_user_data.sh", {
    db_password = var.db_password
    db_name     = var.db_name
  })

  tags = { Name = "${var.project_name}-mysql" }
}

############################
# EC2 Backend (subred privada)
############################

resource "aws_instance" "backend" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  key_name                    = var.key_pair_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  depends_on = [aws_instance.db]

  user_data = templatefile("${path.module}/templates/backend_user_data.sh", {
    aws_region      = var.aws_region
    ecr_registry    = local.ecr_registry
    project_name    = var.project_name
    db_endpoint     = aws_instance.db.private_ip
    db_name         = var.db_name
    db_password     = var.db_password
    image_ventas    = "${local.ecr_registry}/${var.project_name}-backend-ventas:latest"
    image_despachos = "${local.ecr_registry}/${var.project_name}-backend-despachos:latest"
  })

  tags = { Name = "${var.project_name}-backend" }
}

############################
# EC2 Frontend (subred publica)
############################

resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  depends_on = [aws_instance.backend]

  user_data = templatefile("${path.module}/templates/frontend_user_data.sh", {
    aws_region     = var.aws_region
    ecr_registry   = local.ecr_registry
    project_name   = var.project_name
    backend_host   = aws_instance.backend.private_ip
    image_frontend = "${local.ecr_registry}/${var.project_name}-frontend:latest"
  })

  tags = { Name = "${var.project_name}-frontend" }
}
