provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  region                   = "us-east-1"
}


variable "cidr_blocks" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "instance_ami" {}
variable "public_key_location" {}
variable "image_name" {}
variable "instance_name" { type = set(string) }
variable "ingress_ports" {}

############## 9 items to be added incloding servers
#01-vpc
resource "aws_vpc" "mg-dev-vpc" {
  cidr_block = var.cidr_blocks
  tags = {
    Name : "${var.env_prefix}-vpc"
  }
}

#02-igw
resource "aws_internet_gateway" "mg-dev-igw" {
  vpc_id = aws_vpc.mg-dev-vpc.id
  tags = {
    Name : "${var.env_prefix}-igw"
  }
}

#03-rt
resource "aws_route_table" "mg-dev-rt" {
  vpc_id = aws_vpc.mg-dev-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mg-dev-igw.id
  }

  tags = {
    Name : "${var.env_prefix}-rt"
  }
}

#04-subnet
resource "aws_subnet" "mg-dev-subnet01" {
  vpc_id            = aws_vpc.mg-dev-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.avail_zone

  tags = {
    Name : "${var.env_prefix}-sub01"
  }

}

#05-association rt with subnet
resource "aws_route_table_association" "mg-dev-rta" {
  route_table_id = aws_route_table.mg-dev-rt.id
  subnet_id      = aws_subnet.mg-dev-subnet01.id

}

#06-sg
resource "aws_security_group" "mg-dev-sg01" {
  name   = "mg-dev-sg01"
  vpc_id = aws_vpc.mg-dev-vpc.id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.my_ip]
    }

  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name : "${var.env_prefix}-sg01"
  }

}

#07- create public key
resource "aws_key_pair" "ssh_key" {
  key_name   = "mgkey"
  public_key = file(var.public_key_location)
}
#08- create EC2
resource "aws_instance" "mg-dev-server" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.mg-dev-subnet01.id
  vpc_security_group_ids      = [aws_security_group.mg-dev-sg01.id]
  availability_zone           = var.avail_zone
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh_key.key_name
  user_data                   = file("../entry-script-nginx.sh")
  tags = {
    #Name : "${var.env_prefix}-${each.value}"
    Name : each.value
  }
  for_each = var.instance_name

}

output "ec2_public" {
  value = {
    for key, server in aws_instance.mg-dev-server : key => server.public_ip
  }
}