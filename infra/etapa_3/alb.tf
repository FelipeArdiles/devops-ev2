resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-tg-frontend"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-tg-frontend"
  }
}

resource "aws_lb_target_group" "backend_ventas" {
  name        = "${var.project_name}-tg-ventas"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    path                = "/api/v1/ventas"
    matcher             = "200-499"
  }

  tags = {
    Name = "${var.project_name}-tg-ventas"
  }
}

resource "aws_lb_target_group" "backend_despachos" {
  name        = "${var.project_name}-tg-despachos"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    path                = "/api/v1/despachos"
    matcher             = "200-499"
  }

  tags = {
    Name = "${var.project_name}-tg-despachos"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "ventas" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_ventas.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/ventas*"]
    }
  }
}

# NLB interno para MySQL: reemplaza Cloud Map (no permitido en VocLabs).
# Los backends usan este DNS estable como DB_HOST.
resource "aws_lb" "mysql_internal" {
  name               = "${var.project_name}-mysql-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-mysql-nlb"
  }
}

resource "aws_lb_target_group" "mysql" {
  name        = "${var.project_name}-tg-mysql"
  port        = 3306
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled  = true
    protocol = "TCP"
    port     = 3306
  }

  tags = {
    Name = "${var.project_name}-tg-mysql"
  }
}

resource "aws_lb_listener" "mysql" {
  load_balancer_arn = aws_lb.mysql_internal.arn
  port              = 3306
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mysql.arn
  }
}

resource "aws_lb_listener_rule" "despachos" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 101

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_despachos.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/despachos*"]
    }
  }
}
