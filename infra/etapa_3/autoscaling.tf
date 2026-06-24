locals {
  scalable_services = {
    frontend = {
      service_name = aws_ecs_service.frontend.name
      resource_id  = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
    }
    backend_ventas = {
      service_name = aws_ecs_service.backend_ventas.name
      resource_id  = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend_ventas.name}"
    }
    backend_despachos = {
      service_name = aws_ecs_service.backend_despachos.name
      resource_id  = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend_despachos.name}"
    }
  }
}

resource "aws_appautoscaling_target" "ecs" {
  for_each = local.scalable_services

  max_capacity       = var.service_max_count
  min_capacity       = var.service_desired_count
  resource_id        = each.value.resource_id
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = local.scalable_services

  name               = "${var.project_name}-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_target_cpu
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "memory" {
  for_each = local.scalable_services

  name               = "${var.project_name}-${each.key}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_target_cpu
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}
