output "backend_ventas_ecr" {
  value = data.aws_ecr_repository.backend_ventas.repository_url
}
output "backend_despachos_ecr" {
  value = data.aws_ecr_repository.backend_despachos.repository_url
}
output "frontend_ecr" {
  value = data.aws_ecr_repository.frontend.repository_url
}
output "mysql_ip" {
  value = aws_instance.db.public_ip
}