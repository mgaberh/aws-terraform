cidr_blocks         = "10.0.0.0/16"
subnet_cidr_block   = "10.0.10.0/24"
avail_zone          = "us-east-1a"
env_prefix          = "mg-dev"
my_ip               = "0.0.0.0/0"
instance_type       = "t2.micro"
instance_ami        = "ami-09d3b3274b6c5d4aa"
public_key_location = "~/.ssh/id_rsa.pub"
image_name          = "???????????"
instance_name = [
  "mg-dev-server01",
  "mg-dev-server02"
]
ingress_ports = [
  "80",
  "22",
  "8080"
]