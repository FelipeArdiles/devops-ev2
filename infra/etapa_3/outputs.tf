output "alb_dns_name" {
  description = "URL publica del frontend (Application Load Balancer)"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "URL HTTP completa de la aplicacion"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN del cluster ECS"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_services" {
  description = "Nombres de servicios ECS desplegados"
  value = {
    frontend          = aws_ecs_service.frontend.name
    backend_ventas    = aws_ecs_service.backend_ventas.name
    backend_despachos = aws_ecs_service.backend_despachos.name
    mysql             = aws_ecs_service.mysql.name
  }
}

output "cloudwatch_log_groups" {
  description = "Grupos de logs en CloudWatch"
  value = {
    frontend          = aws_cloudwatch_log_group.frontend.name
    backend_ventas    = aws_cloudwatch_log_group.backend_ventas.name
    backend_despachos = aws_cloudwatch_log_group.backend_despachos.name
    mysql             = aws_cloudwatch_log_group.mysql.name
  }
}

output "autoscaling_target_cpu" {
  description = "Umbral CPU configurado para autoscaling"
  value       = var.autoscaling_target_cpu
}

output "ecr_backend_ventas_url" {
  value = data.aws_ecr_repository.backend_ventas.repository_url
}

output "ecr_backend_despachos_url" {
  value = data.aws_ecr_repository.backend_despachos.repository_url
}

output "ecr_frontend_url" {
  value = data.aws_ecr_repository.frontend.repository_url
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "mysql_nlb_dns_name" {
  description = "DNS del NLB interno para conexion MySQL (DB_HOST de backends)"
  value       = aws_lb.mysql_internal.dns_name
}
