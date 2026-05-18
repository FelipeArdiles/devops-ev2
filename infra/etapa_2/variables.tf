variable "aws_region" {
  default = "us-east-1"
}
variable "project_name" {
  default = "devops-u2"
}
variable "db_user" {
  default = "root"
}
variable "db_password" {}
variable "db_name" {
  default = "proyecto_db"
}
variable "key_pair_name" {
  description = "Key Pair de EC2 para SSH a la instancia MySQL (p. ej. vockey en AWS Academy)."
  default     = "vockey"
}