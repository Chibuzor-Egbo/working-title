# vpc
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

# first public subnet (app)
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.pub1_cidr
  map_public_ip_on_launch = true
}

# second public subnet (monitoring)
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.pub2_cidr
  map_public_ip_on_launch = true
}

# private subnet 1 (RDS)
resource "aws_subnet" "private1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.priv1_cidr
  map_public_ip_on_launch = false
  availability_zone       = var.az1
}

# private subnet 2 (RDS)
resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.priv2_cidr
  map_public_ip_on_launch = false
  availability_zone       = var.az2
}

# db subnet group

resource "aws_db_subnet_group" "main" {
  name = "main-db-subnet-group"

  subnet_ids = [
    aws_subnet.private1.id, aws_subnet.private2.id
  ]

  tags = {
    Name = "Main DB subnet group"
  }
}



# internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

# route entry for specifying how the public subnets should access the internet
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# associating the route table to public subnet 1
resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

# associating the route table to public subnet 2
resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}