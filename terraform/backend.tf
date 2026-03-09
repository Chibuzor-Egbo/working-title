terraform {
  backend "s3" {
    bucket         = "workingtitle-terraform-state-bucket"
    key            = "deploy-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
  }
}