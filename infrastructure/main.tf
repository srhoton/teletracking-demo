terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    bucket = "srhoton-tfstate"
    key    = "teletracking-demo.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-west-2"
}

variable "default_vpc_cidr" {
  type = string
}

variable "blue_subnet_cidr" {
  type = string
}

variable "red_subnet_cidr" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

resource "aws_vpc" "default_vpc" {
  cidr_block = var.default_vpc_cidr
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.default_vpc.id
}

resource "aws_subnet" "blue_subnet" {
  vpc_id     = aws_vpc.default_vpc.id
  cidr_block = var.blue_subnet_cidr 
  map_public_ip_on_launch = true

  tags = {
    Name = "Default Subnet Blue"
  }
}

resource "aws_subnet" "red_subnet" {
  vpc_id     = aws_vpc.default_vpc.id
  cidr_block = var.red_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name = "Default Subnet Red"
  }
}


resource "aws_security_group" "ec2_security_group" {
  name        = "teletracking-ec2-sg"
  description = "Security group for Teletracking EC2 instances"
  vpc_id      = aws_vpc.default_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_security_group" {
  name        = "teletracking-alb-sg"
  description = "Security group for Teletracking ALB"
  vpc_id      = aws_vpc.default_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "blue_data" {
  template = file("./blue_data.tpl")
}

resource "aws_instance" "blue_machine" {
  ami           = var.ami_id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  subnet_id  = aws_subnet.blue_subnet.id
  key_name = "teletracking-demo"
  user_data = data.template_file.blue_data.rendered
}

data "template_file" "red_data" {
  template = file("./red_data.tpl")
}

resource "aws_instance" "red_machine" {
  ami           = var.ami_id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  subnet_id  = aws_subnet.red_subnet.id
  key_name = "teletracking-demo"
  user_data = data.template_file.red_data.rendered
}

resource "aws_lb_target_group" "alb_target_group" {
  name     = "teletracking-demo-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.default_vpc.id
}

resource "aws_lb_target_group_attachment" "blue_attachment" {
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.blue_machine.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "red_attachment" {
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.red_machine.id
  port             = 8080
}

resource "aws_lb" "teletracking_lb" {
  name               = "teletracking-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [aws_subnet.blue_subnet.id,aws_subnet.red_subnet.id]

  tags = {
    Environment = "teletracking-demo"
  }
}

resource "aws_lb_listener" "teletracking_listener" {
  load_balancer_arn = aws_lb.teletracking_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

output "alb_arn" {
  value = aws_lb.teletracking_lb.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.alb_target_group.arn
}

