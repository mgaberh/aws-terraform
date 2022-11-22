cidr_blocks               = "10.0.0.0/16"
public_subnet_cidr_block  = "10.0.0.0/24"
private_subnet_cidr_block = "10.0.1.0/24"
avail_zone                = "us-east-1a"
env_prefix                = "mg-dev"
my_ip                     = "0.0.0.0/0"
instance_type             = "t2.micro"
instance_ami              = "ami-09d3b3274b6c5d4aa"
public_key_location       = "~/.ssh/id_rsa.pub"
image_name                = "???????????"
public_instance_name = [
  "mg-dev-public-server01",
  "mg-dev-public-server02"
]
private_instance_name = [
  "mg-dev-private-server01",
  "mg-dev-private-server02"
]
ingress_ports = [
  "80",
  "22",
  "8080"
]