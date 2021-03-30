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
  region = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_access_key
}

resource "aws_vpc" "my-web-vpc" {
  cidr_block  = "10.0.0.0/16"

  tags = {
    Name = "my-web-vpc"
  }
}

resource "aws_subnet" "my-web-subnet1" {
  vpc_id     = aws_vpc.my-web-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = var.subnet-value-1

  tags = {
    Name = "my-web-subnet1"
  }
}

resource "aws_subnet" "my-web-subnet2" {
  vpc_id     = aws_vpc.my-web-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = var.subnet-value-2

  tags = {
    Name = "my-web-subnet2"
  }
}

resource "aws_internet_gateway" "my-web-igw" {
  vpc_id = aws_vpc.my-web-vpc.id

  tags = {
    Name = "my-web-igw"
  }
}

resource "aws_route_table" "my-web-rt" {
  vpc_id = aws_vpc.my-web-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-web-igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.my-web-igw.id
  }

  tags = {
    Name = "my-web-rt"
  }
}

resource "aws_route_table_association" "my-web-assoc1" {
  subnet_id      = aws_subnet.my-web-subnet1.id
  route_table_id = aws_route_table.my-web-rt.id
}

resource "aws_route_table_association" "my-web-assoc2" {
  subnet_id      = aws_subnet.my-web-subnet2.id
  route_table_id = aws_route_table.my-web-rt.id
}

resource "aws_security_group" "sg-lb" {
  name        = "lb-sg"
  description = "Allow web inbound traffic to lb"
  vpc_id      = aws_vpc.my-web-vpc.id

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
    Name = "sg-lb"
  }
}

resource "aws_security_group" "sg-web-instance" {
  name        = "web_instance_sg"
  description = "Allow web inbound traffic from lb only"
  vpc_id      = aws_vpc.my-web-vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.sg-lb.id]
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
    Name = "sg_web_instance"
  }
}

resource "aws_instance" "web-server1" {
  ami           = "ami-0db9040eb3ab74509"
  instance_type = "t2.micro"
  key_name = "iamuser"
  associate_public_ip_address = true
  subnet_id = aws_subnet.my-web-subnet1.id
  private_ip = "10.0.1.100"

  security_groups = [aws_security_group.sg-web-instance.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install httpd -y
              systemctl start httpd
              systemctl enable httpd
              bash -c 'echo "Hello from $(hostname -f)" > /var/www/html/index.html'
              EOF

  tags = {
    Name = "web-server-1"
  }
}

resource "aws_instance" "web-server2" {
  ami           = "ami-0db9040eb3ab74509"
  instance_type = "t2.micro"
  key_name = "iamuser"
  associate_public_ip_address = true
  subnet_id = aws_subnet.my-web-subnet2.id
  private_ip = "10.0.2.100"

  security_groups = [aws_security_group.sg-web-instance.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install httpd -y
              systemctl start httpd
              systemctl enable httpd
              bash -c 'echo "Hello from $(hostname -f)" > /var/www/html/index.html'
              EOF

  tags = {
    Name = "web-server-2"
  }
}

resource "aws_lb" "my-web-alb" {
  name               = "my-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg-lb.id]
  subnets            = [aws_subnet.my-web-subnet1.id, aws_subnet.my-web-subnet2.id]

  tags = {
    Environment = "web"
    Name = "web-alb"
  }
}

resource "aws_lb_target_group" "web-tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.my-web-vpc.id

  health_check {
    path = "/"
    matcher = "200"
  }
}

resource "aws_lb_target_group_attachment" "tg-attach-1" {
  target_group_arn = aws_lb_target_group.web-tg.arn
  target_id        = aws_instance.web-server1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg-attach-2" {
  target_group_arn = aws_lb_target_group.web-tg.arn
  target_id        = aws_instance.web-server2.id
  port             = 80
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.my-web-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-tg.arn
  }
}

resource "aws_lb_listener_rule" "front-end" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb.my-web-alb.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }

  depends_on = [
    aws_lb_listener.front_end
  ]
}