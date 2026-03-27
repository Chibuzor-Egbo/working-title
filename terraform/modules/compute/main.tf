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
    cidr_blocks = [var.my_ip]
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

# EC2 instance for the app

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = aws_key_pair.app_key.key_name

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
