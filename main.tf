terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "access-key"
  secret_key = "secret-access-key"
}


# 1. Create a VPC
resource "aws_vpc" "tf" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-vpc"
  }
}
# 2. Create a subnet within this VPC
resource "aws_subnet" "tf" {
  vpc_id     = aws_vpc.tf.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "terraform-subnet"
  }
}
# 3. Create an IGW for this VPC
resource "aws_internet_gateway" "tf" {
  vpc_id = aws_vpc.tf.id

  tags = {
    Name = "terraform-igw"
  }
}
# 4. Create a route table for the VPC
resource "aws_route_table" "tf" {
  vpc_id = aws_vpc.tf.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.tf.id
  }

  tags = {
    Name = "terraform-rt-table"
  }
}
# 5. Route table association with the subnet
resource "aws_route_table_association" "tf" {
  subnet_id      = aws_subnet.tf.id
  route_table_id = aws_route_table.tf.id
  
}
# 6. Create an EC2 instance(Ubuntu Server with apache2) within this subnet
resource "aws_instance" "tf" {
  ami           = "ami-042e8287309f5df03"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "tf-key-pair"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.tf.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo my first web server through terraform! > /var/www/html/index.html'
              EOF

  tags = {
    Name = "terraform-web-server"
  }
}
# 7. Create security group for web traffic for the EC2 instance
resource "aws_security_group" "tf" {
  name        = "allow_web"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.tf.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-sg-allow_web"
  }
}

# 8. Create a network interface associated with this elastic IP and attached to the instance
resource "aws_network_interface" "tf" {
  subnet_id       = aws_subnet.tf.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.tf.id]

}

# 9. Create an Elastic IP for the instance
resource "aws_eip" "tf" {
  vpc                       = true
  network_interface         = aws_network_interface.tf.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.tf
  ]
}

