variable "subnet_ids_db" {
  description = "list of private subnet ids"
  type        = list(string)
}

variable "vpc_id" {
  description = "id for the vpc"
  type        = string
}

variable "app_sg" {
  description = "security group for the app instance"
  type        = string
}

variable "db_user" {
  description = "username for database"
  type        = string
}

variable "db_password" {
  description = "password for database"
  type        = string
  sensitive   = true
}