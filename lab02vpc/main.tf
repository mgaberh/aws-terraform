provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  region                   = "us-east-1"
}


variable "cidr_blocks" {}
variable "public_subnet_cidr_block" {}
variable "private_subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "instance_ami" {}
variable "public_key_location" {}
variable "image_name" {}
variable "public_instance_name" { type = set(string) }
variable "private_instance_name" { type = set(string) }
variable "ingress_ports" {}

############# 17 items to be added incloding servers
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

#03-public route table
resource "aws_route_table" "mg-dev-public-rt" {
  vpc_id = aws_vpc.mg-dev-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mg-dev-igw.id
  }

  tags = {
    Name : "${var.env_prefix}-public-rt"
  }
}

#04-public subnet
resource "aws_subnet" "mg-dev-public-subnet" {
  vpc_id                  = aws_vpc.mg-dev-vpc.id
  cidr_block              = var.public_subnet_cidr_block
  map_public_ip_on_launch = true #public subnet
  availability_zone       = var.avail_zone

  tags = {
    Name : "${var.env_prefix}-public-subnet"
  }

}

#05-association public rt with public subnet
resource "aws_route_table_association" "mg-dev-public-rta" {
  route_table_id = aws_route_table.mg-dev-public-rt.id
  subnet_id      = aws_subnet.mg-dev-public-subnet.id

}

#06 - eip for nat
resource "aws_eip" "nat_eip" {
  vpc = true
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.mg-dev-igw]
}

#07 nat gateway
resource "aws_nat_gateway" "mg-dev-ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.mg-dev-public-subnet.id
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.mg-dev-igw]

  tags = {
    Name : "${var.env_prefix}-ngw"
  }


}

#08-private route table
resource "aws_route_table" "mg-dev-priavte-rt" {
  vpc_id = aws_vpc.mg-dev-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mg-dev-ngw.id
    #gateway_id  = aws_internet_gateway.mg-dev-igw.id
  }

  tags = {
    Name : "${var.env_prefix}-priavte-rt"
  }
}

#09-priavte subnet
resource "aws_subnet" "mg-dev-priavte-subnet" {
  vpc_id                  = aws_vpc.mg-dev-vpc.id
  cidr_block              = var.private_subnet_cidr_block
  map_public_ip_on_launch = false #private subnet - default is false
  availability_zone       = var.avail_zone

  tags = {
    Name : "${var.env_prefix}-priavte-subnet"
  }

}

#10-association priavte rt with priavte subnet
resource "aws_route_table_association" "mg-dev-priavte-rta" {
  route_table_id = aws_route_table.mg-dev-priavte-rt.id
  subnet_id      = aws_subnet.mg-dev-priavte-subnet.id

}

#11-sg for public access
resource "aws_security_group" "mg-dev-public-sg" {
  name   = "mg-dev-public-sg"
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
    Name : "${var.env_prefix}-public-sg"
  }

}

#12- create public key
resource "aws_key_pair" "ssh_key" {
  key_name   = "mgkey"
  public_key = file(var.public_key_location)
}
#13- create EC2
resource "aws_instance" "mg-dev-public-server" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.mg-dev-public-subnet.id
  vpc_security_group_ids      = [aws_security_group.mg-dev-public-sg.id]
  availability_zone           = var.avail_zone
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh_key.key_name
  user_data                   = file("../entry-script-nginx.sh")
  tags = {
    #Name : "${var.env_prefix}-${each.value}"
    Name : each.value
  }
  for_each = var.public_instance_name

}

#14-sg for private access
resource "aws_security_group" "mg-dev-private-sg" {
  name   = "mg-dev-private-sg"
  vpc_id = aws_vpc.mg-dev-vpc.id

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }

  tags = {
    Name : "${var.env_prefix}-private-sg"
  }

}

#15- create EC2
resource "aws_instance" "mg-dev-private-server" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.mg-dev-priavte-subnet.id
  vpc_security_group_ids      = [aws_security_group.mg-dev-private-sg.id]
  availability_zone           = var.avail_zone
  associate_public_ip_address = false
  key_name                    = aws_key_pair.ssh_key.key_name
  user_data                   = file("../entry-script-nginx.sh")
  tags = {
    #Name : "${var.env_prefix}-${each.value}"
    Name : each.value
  }
  for_each = var.private_instance_name

}


output "ec2_public" {
  value = {
    for key, server in aws_instance.mg-dev-public-server : key => server.public_ip
  }
}
output "ec2_private" {
  value = {
    for key, server in aws_instance.mg-dev-private-server : key => server.arn
  }
}