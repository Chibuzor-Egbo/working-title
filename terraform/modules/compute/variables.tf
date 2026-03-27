variable "vpc_id" {
  description = "Identifier for the vpc"
  type        = string
}

variable "my_ip" {
  description = "my public IP at the time of application"
  type        = string
}

# variable "ami_id" {
#   description = "AMI ID for app instance"
#   type = string
# }

variable "instance_type" {
  description = "Instance type for app instance"
  type        = string
}

variable "subnet_id" {
  description = "public subnet for the app EC2 instance"
  type        = string
}