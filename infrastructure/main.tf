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


resource "aws_vpc" "default_vpc" {
  cidr_block = "172.31.0.0/16"
}

resource "aws_subnet" "default_subnet_one" {
  vpc_id     = aws_vpc.default_vpc.id
  cidr_block = "172.31.0.0/20"
  map_public_ip_on_launch = true

  tags = {
    Name = "Default Subnet One"
  }
}

resource "aws_subnet" "default_subnet_two" {
  vpc_id     = aws_vpc.default_vpc.id
  cidr_block = "172.31.48.0/20"
  map_public_ip_on_launch = true

  tags = {
    Name = "Default Subnet One"
  }
}
