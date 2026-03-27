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
resource "aws_key_pair" "mon_key" {
  key_name   = "mon-key"
  public_key = file("mon-key.pub")
}

# Security group for monitoring instance

resource "aws_security_group" "mon_sg" {
  name   = "mon-security-group"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # grafana dashboard
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  #prometheus on web
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  #loki on web (tentative)
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# IAM role for the monitoring server

resource "aws_iam_role" "ec2_admin_role" {
  name = "ec2-admin-role-mon"

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

# IAM policy attached to the role for the monitoring server

resource "aws_iam_role_policy_attachment" "admin_policy" {
  role       = aws_iam_role.ec2_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

#  IAM instance profile for the monitoring server

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-admin-profile-mon"
  role = aws_iam_role.ec2_admin_role.name
}

# monitoring server

resource "aws_instance" "mon" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  subnet_id            = var.subnet_id
  key_name             = aws_key_pair.mon_key.key_name

  vpc_security_group_ids = [aws_security_group.mon_sg.id]
}