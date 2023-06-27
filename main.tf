terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-south-1"
}

variable "dev-vpc-cidr-block" {
  description = "development vpc cidr block"
}

variable "dev-subnet-cidr-block" {
  description = "development subnet cidr block"
}

variable "env-prefix" {
  description = "environment prefix"
}

variable "availability_zone" {
  description = "availability zone"  
}

variable "instance-type" {
  description = "instance type"  
}

resource "aws_vpc" "development-vpc" {
  cidr_block = var.dev-vpc-cidr-block
  tags = {
    Name = "${var.env-prefix}-vpc"
  }
}

resource "aws_subnet" "development-subnet-1" {
  vpc_id            = aws_vpc.development-vpc.id
  cidr_block        = var.dev-subnet-cidr-block
  availability_zone = var.availability_zone
  tags = {
    Name = "${var.env-prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "dev-igw" {
  vpc_id = aws_vpc.development-vpc.id

  tags = {
    Name = "${var.env-prefix}-igw"
  }

}

resource "aws_default_route_table" "dev-main-rt" {
  default_route_table_id = aws_vpc.development-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-igw.id
  }
  tags = {
    Name = "${var.env-prefix}-main-rtb"
  }
}

resource "aws_default_security_group" "dev-sg" {
  vpc_id = aws_vpc.development-vpc.id
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.env-prefix}-sg"
  }
}

data "aws_ami" "amazon-ubuntu-machine-image" {
  most_recent = true
  owners = [ "amazon" ]
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20230516"]
  }
}

resource "aws_instance" "ec2-instance" {
  ami = data.aws_ami.amazon-ubuntu-machine-image.id
  instance_type = var.instance-type

  subnet_id = aws_subnet.development-subnet-1.id
  vpc_security_group_ids = [ aws_default_security_group.dev-sg.id ]
  availability_zone = var.availability_zone

  associate_public_ip_address = true
  key_name = "Jenkins-Server-KP"

  user_data = file("entry-script.sh")

  tags = {
    Name = "${var.env-prefix}-server"
  }
}