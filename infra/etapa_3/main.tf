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

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ecr_repository" "backend_ventas" {
  name = "${var.project_name}-backend-ventas"
}

data "aws_ecr_repository" "backend_despachos" {
  name = "${var.project_name}-backend-despachos"
}

data "aws_ecr_repository" "frontend" {
  name = "${var.project_name}-frontend"
}
