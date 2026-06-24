# AWS Academy VocLabs no permite iam:CreateRole.
# Usar el rol preexistente del learner lab (por defecto "LabRole").
# Si tu lab usa otro nombre, ajusta las variables ecs_execution_role_name / ecs_task_role_name.
data "aws_iam_role" "ecs_execution" {
  name = var.ecs_execution_role_name
}

data "aws_iam_role" "ecs_task" {
  name = var.ecs_task_role_name
}
