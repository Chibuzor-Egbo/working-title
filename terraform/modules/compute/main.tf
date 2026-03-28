# Data source for ami

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Key pair for SSH
resource "aws_key_pair" "app_key" {
  key_name   = "wt-key"
  public_key = file("wt-key.pub")
}

# Security group for app instance

resource "aws_security_group" "app_sg" {
  name   = "wt-security-group"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# IAM role for the app server
resource "aws_iam_role" "ec2_admin_role" {
  name = "ec2-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy attached to the role for the app server

resource "aws_iam_role_policy_attachment" "admin_policy" {
  role       = aws_iam_role.ec2_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

#  IAM instance profile for the app server

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-admin-profile"
  role = aws_iam_role.ec2_admin_role.name
}

# EC2 instance for the app

resource "aws_instance" "app" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  subnet_id            = var.subnet_id
  key_name             = aws_key_pair.app_key.key_name

  vpc_security_group_ids = [aws_security_group.app_sg.id]
}

# Elastic IP for app

resource "aws_eip" "app_ip" {
  domain = "vpc"
}

# EIP association

resource "aws_eip_association" "app_ip_assoc" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app_ip.id
}

# ELASTIC CONTAINER REGISTRY - repo creation

resource "aws_ecr_repository" "this" {
  name = "wt"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true
}

# Github OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}


# IAM role for GitHub Actions
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:Chibuzor-Egbo/working-title:*"
          }
        }
      }
    ]
  })
}

# Attach combined policy for Terraform backend + ECR
# resource "aws_iam_role_policy" "github_actions_policy" {
#   role = aws_iam_role.github_actions_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       # S3 bucket access for Terraform state
#       {
#         Effect   = "Allow"
#         Action   = ["s3:ListBucket"]
#         Resource = "arn:aws:s3:::workingtitle-terraform-state-bucket"
#       },
#       {
#         Effect   = "Allow"
#         Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
#         Resource = "arn:aws:s3:::workingtitle-terraform-state-bucket/*"
#       },

#       # DynamoDB table access for Terraform state locking
#       {
#         Effect   = "Allow"
#         Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:UpdateItem"]
#         Resource = "arn:aws:dynamodb:us-east-1:162322546212:table/terraform-state-locks"
#       },

#       # ECR access for pushing Docker images
#       {
#         Effect = "Allow"
#         Action = [
#           "ecr:GetAuthorizationToken",
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:CompleteLayerUpload",
#           "ecr:UploadLayerPart",
#           "ecr:InitiateLayerUpload",
#           "ecr:PutImage"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# give admin access to github OIDC
resource "aws_iam_role_policy_attachment" "github_admin" {
  role = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


