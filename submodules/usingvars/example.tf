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
  region = "eu-central-1"
  # defined in env --> export TF_VAR_access_key_value="<access-key>"
  # to check value --> echo $TF_VAR_access_key_value
  access_key = var.access_key_value

  # defined in env --> export TF_VAR_secret_access_key_value="<secret-access-key>"
  # to check value --> echo $TF_VAR_secret_access_key_value
  secret_key = var.secret_access_key_value
}

resource "aws_vpc" "dev" {
  cidr_block  = "10.1.0.0/16"

  tags = {
    Name = "dev-vpc"
  }
}

resource "aws_subnet" "dev" {
  vpc_id     = aws_vpc.dev.id
  cidr_block = var.subnet_values[0].cidr_block
  availability_zone = "eu-central-1a"

  tags = {
    Name = var.subnet_values[0].name
  }
}

resource "aws_subnet" "dev2" {
  vpc_id     = aws_vpc.dev.id
  cidr_block = var.subnet_values[1].cidr_block
  availability_zone = "eu-central-1b"

  tags = {
    Name = var.subnet_values[1].name
  }
}

resource "aws_internet_gateway" "dev" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_network_interface" "web-server-eni" {
  subnet_id   = aws_subnet.dev2.id
  private_ips = var.web-server-private-ips

  tags = {
    Name = "dev_network_interface"
  }

  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_instance" "web-server" {
  ami           = "ami-013fffc873b1eaa1c"
  instance_type = "t2.micro"
  key_name = "iamuser"

  network_interface {
    network_interface_id = aws_network_interface.web-server-eni.id
    device_index         = 0
  }

  tags = {
    Name = "web-server-dev"
  }
}

resource "aws_eip" "dev-eni" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-eni.id
  associate_with_private_ip = var.web-server-private-ips[0]

  depends_on = [
    aws_internet_gateway.dev
  ]
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.dev.id

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
    Name = "allow_web_traffic"
  }
}

resource "aws_route_table" "dev" {
  vpc_id = aws_vpc.dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.dev.id
  }

  tags = {
    Name = "dev-rt"
  }
}

resource "aws_route_table_association" "dev" {
  subnet_id      = aws_subnet.dev2.id
  route_table_id = aws_route_table.dev.id
}

output "web-server-public-ip"{
    value = aws_eip.dev-eni.public_ip
}