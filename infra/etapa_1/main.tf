terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#ECR: necesitamos 3 elementos en ECR
resource "aws_ecr_repository" "backend_ventas" {
  name = "${var.nombre_proyecto}-backend-ventas"
  force_delete = true
}

resource "aws_ecr_repository" "backend_despachos" {
  name = "${var.nombre_proyecto}-backend-despachos"
  force_delete = true
}

resource "aws_ecr_repository" "frontend" {
  name = "${var.nombre_proyecto}-frontend"
  force_delete = true
}