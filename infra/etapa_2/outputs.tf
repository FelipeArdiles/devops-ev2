output "frontend_public_ip" {
  description = "IP publica del frontend (unico punto de acceso desde Internet)"
  value       = aws_instance.frontend.public_ip
}

output "backend_private_ip" {
  description = "IP privada del servidor de backends (subred privada)"
  value       = aws_instance.backend.private_ip
}

output "mysql_private_ip" {
  description = "IP privada de MySQL"
  value       = aws_instance.db.private_ip
}

output "frontend_url" {
  value = "http://${aws_instance.frontend.public_ip}/"
}

output "ecr_registry" {
  value = local.ecr_registry
}

output "backend_ventas_ecr" {
  value = data.aws_ecr_repository.backend_ventas.repository_url
}

output "backend_despachos_ecr" {
  value = data.aws_ecr_repository.backend_despachos.repository_url
}

output "frontend_ecr" {
  value = data.aws_ecr_repository.frontend.repository_url
}
