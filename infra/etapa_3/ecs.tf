resource "aws_cloudwatch_log_group" "mysql" {
  name              = "/ecs/${var.project_name}/mysql"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs-mysql"
  }
}

resource "aws_cloudwatch_log_group" "backend_ventas" {
  name              = "/ecs/${var.project_name}/backend-ventas"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs-backend-ventas"
  }
}

resource "aws_cloudwatch_log_group" "backend_despachos" {
  name              = "/ecs/${var.project_name}/backend-despachos"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs-backend-despachos"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}/frontend"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs-frontend"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

resource "aws_ecs_task_definition" "mysql" {
  family                   = "${var.project_name}-mysql"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_execution.arn
  task_role_arn            = data.aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "mysql"
    image     = "mysql:8"
    essential = true
    portMappings = [{
      containerPort = 3306
      protocol      = "tcp"
    }]
    environment = [
      { name = "MYSQL_ROOT_PASSWORD", value = var.db_password },
      { name = "MYSQL_DATABASE", value = var.db_name },
      { name = "MYSQL_ROOT_HOST", value = "%" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.mysql.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "mysql"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "mysqladmin ping -h localhost -p${var.db_password} || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

resource "aws_ecs_task_definition" "backend_ventas" {
  family                   = "${var.project_name}-backend-ventas"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_execution.arn
  task_role_arn            = data.aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "backend-ventas"
    image     = "${data.aws_ecr_repository.backend_ventas.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    environment = [
      { name = "DB_HOST", value = aws_lb.mysql_internal.dns_name },
      { name = "DB_PORT", value = "3306" },
      { name = "DB_ENDPOINT", value = aws_lb.mysql_internal.dns_name },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USERNAME", value = "root" },
      { name = "DB_PASSWORD", value = var.db_password }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend_ventas.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend-ventas"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "backend_despachos" {
  family                   = "${var.project_name}-backend-despachos"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.ecs_execution.arn
  task_role_arn            = data.aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "backend-despachos"
    image     = "${data.aws_ecr_repository.backend_despachos.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8081
      protocol      = "tcp"
    }]
    environment = [
      { name = "DB_HOST", value = aws_lb.mysql_internal.dns_name },
      { name = "DB_PORT", value = "3306" },
      { name = "DB_ENDPOINT", value = aws_lb.mysql_internal.dns_name },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USERNAME", value = "root" },
      { name = "DB_PASSWORD", value = var.db_password }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend_despachos.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend-despachos"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_execution.arn
  task_role_arn            = data.aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = "${data.aws_ecr_repository.frontend.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])
}

resource "aws_ecs_service" "mysql" {
  name            = "${var.project_name}-mysql"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mysql.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mysql.arn
    container_name   = "mysql"
    container_port   = 3306
  }

  depends_on = [aws_lb_listener.mysql]

  tags = {
    Name = "${var.project_name}-mysql-service"
  }
}

resource "aws_ecs_service" "backend_ventas" {
  name                               = "${var.project_name}-backend-ventas"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.backend_ventas.arn
  desired_count                      = var.service_desired_count
  launch_type                        = "FARGATE"
  health_check_grace_period_seconds  = 180

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_ventas.arn
    container_name   = "backend-ventas"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_service.mysql
  ]

  tags = {
    Name = "${var.project_name}-backend-ventas-service"
  }
}

resource "aws_ecs_service" "backend_despachos" {
  name                               = "${var.project_name}-backend-despachos"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.backend_despachos.arn
  desired_count                      = var.service_desired_count
  launch_type                        = "FARGATE"
  health_check_grace_period_seconds  = 180

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_despachos.arn
    container_name   = "backend-despachos"
    container_port   = 8081
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_service.mysql
  ]

  tags = {
    Name = "${var.project_name}-backend-despachos-service"
  }
}

resource "aws_ecs_service" "frontend" {
  name                               = "${var.project_name}-frontend"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.frontend.arn
  desired_count                      = var.service_desired_count
  launch_type                        = "FARGATE"
  health_check_grace_period_seconds  = 120

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${var.project_name}-frontend-service"
  }
}
