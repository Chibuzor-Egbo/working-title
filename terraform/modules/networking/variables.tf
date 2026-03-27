variable "vpc_cidr" {
  description = "IP address range for the VPC"
  type        = string
}

variable "pub1_cidr" {
  description = "IP address range for the Public Subnet 1"
  type        = string
}

variable "pub2_cidr" {
  description = "IP address range for the Public Subnet 2"
  type        = string
}

variable "priv1_cidr" {
  description = "IP address range for the First Private Subnet"
  type        = string
}

variable "priv2_cidr" {
  description = "IP address range for the Second Private Subnet"
  type        = string
}

variable "az1" {
  description = "Availability zone for the first DB subnet"
  type        = string
}

variable "az2" {
  description = "Availability zone for the first DB subnet"
  type        = string
}