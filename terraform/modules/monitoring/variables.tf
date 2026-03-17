variable "my_ip" {
  description = "my current public ip"
  type        = string
}

variable "vpc_id" {
  description = "identifier for the vpc"
  type        = string
}

variable "instance_type" {
  description = "instance type"
  type        = string
}

variable "subnet_id" {
  description = "id for the second public subnet (for monitoring servers)"
  type        = string
}