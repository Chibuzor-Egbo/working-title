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