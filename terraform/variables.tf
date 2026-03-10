variable "aws_region" {
  description = "AWS region to deploy boostrap resources"
  type        = string
}

variable "bucket_name" {
  description = "Name of S3 bucket for bootstrapping"
  type        = string
}

variable "dynamodbtable_name" {
  description = "Name of Dynamo db table for bootstrapping"
  type        = string
}

# Networking Variables

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

# Compute (App) Variables

# variable "ami_id" {
#   description = "AMI ID for app instance"
#   type = string
# }

variable "instance_type" {
  description = "Instance type for app instance"
  type        = string
}

variable "my_ip" {
  description = "my public IP at the time of application"
  type        = string
}