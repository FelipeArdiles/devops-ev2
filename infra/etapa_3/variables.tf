variable "aws_region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto (prefijo de recursos)"
  type        = string
  default     = "devops-u2"
}

variable "db_password" {
  description = "Contrasena root de MySQL"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "proyecto_db"
}

variable "autoscaling_target_cpu" {
  description = "Umbral CPU para autoscaling (Target Tracking)"
  type        = number
  default     = 50
}

variable "service_desired_count" {
  description = "Numero inicial de tareas por servicio"
  type        = number
  default     = 1
}

variable "service_max_count" {
  description = "Maximo de tareas por servicio (autoscaling)"
  type        = number
  default     = 3
}

variable "ecs_execution_role_name" {
  description = "Nombre del rol IAM de ejecucion ECS existente en VocLabs (tipicamente LabRole)"
  type        = string
  default     = "LabRole"
}

variable "ecs_task_role_name" {
  description = "Nombre del rol IAM de tarea ECS existente en VocLabs (tipicamente LabRole)"
  type        = string
  default     = "LabRole"
}
